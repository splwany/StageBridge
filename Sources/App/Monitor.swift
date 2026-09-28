import AppKit
import ServiceManagement

final class DisplayMonitor: ObservableObject {
  static let intervals = [15, 30, 60, 120, 300]
  @Published private(set) var enabled = false
  @Published private(set) var interval = 60
  @Published private(set) var displayStatus = "读取显示器状态…"
  @Published private(set) var lastAction = "启动时只记录连接状态。"
  @Published private(set) var loginEnabled = false
  @Published private(set) var loginNeedsApproval = false
  @Published var errorMessage: String?
  @Published private(set) var attention: String?
  private var policy = ConnectionPolicy()
  private var listening = false
  private var timer: ScheduledAction?
  private var pending: ScheduledAction?
  private var observers: [NSObjectProtocol] = []
  private var lifecycle = MonitorLifecycle()
  private var wakeTask: ScheduledAction?
  private var controlTask: Task<Void, Never>?
  private var operationID = UUID()
  private var suspended: Bool { lifecycle.suspended }
  private let defaults: UserDefaults
  private let events: DisplayEventSource
  private let scheduler: MonitorScheduler
  private let readConnected: () throws -> Bool
  private let apply: (Bool) async throws -> StageManagerOutcome
  private let notificationCenter: NotificationCenter
  private let logger: EventLogger
  var logURL: URL { logger.url }

  init(
    defaults: UserDefaults = .standard,
    events: DisplayEventSource = DisplayEvents(),
    scheduler: MonitorScheduler = MainQueueScheduler(),
    readConnected: @escaping () throws -> Bool = DisplayReader.externalConnected,
    apply: @escaping (Bool) async throws -> StageManagerOutcome = {
      try await StageManagerControl.apply($0)
    },
    notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
    home: URL = FileManager.default.homeDirectoryForCurrentUser
  ) {
    self.defaults = defaults
    self.events = events
    self.scheduler = scheduler
    self.readConnected = readConnected
    self.apply = apply
    self.notificationCenter = notificationCenter
    self.logger = EventLogger(
      url: home.appendingPathComponent("Library/Logs/StageByScreen/events.log"))
    interval = defaults.integer(forKey: "PollSeconds")
    if !Self.intervals.contains(interval) { interval = 60 }
    enabled = defaults.bool(forKey: "Enabled")
    refreshLogin()
    baseline()
    let center = notificationCenter
    for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
      observers.append(
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
          guard let self else { return }
          self.lifecycle.sleep(screen: note.name == NSWorkspace.screensDidSleepNotification)
          self.cancelControl()
          self.wakeTask?.cancel()
          self.wakeTask = nil
          self.pending?.cancel()
          self.pending = nil
        })
    }
    for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
      observers.append(
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
          guard let self else { return }
          self.lifecycle.wake(screen: note.name == NSWorkspace.screensDidWakeNotification)
          self.cancelControl()
          self.pending?.cancel()
          self.pending = nil
          self.wakeTask?.cancel()
          self.wakeTask = self.scheduler.once(after: 3) { [weak self] in
            guard let self else { return }
            self.wakeTask = nil
            if self.lifecycle.finishSettling() { self.baseline() }
          }
        })
    }
    if enabled { _ = start() }
    log("App started; enabled=\(enabled); interval=\(interval)")
  }

  func setEnabled(_ value: Bool) {
    stop()
    enabled = value
    defaults.set(value, forKey: "Enabled")
    if !suspended { baseline() }
    if value && !start() { return }
    lastAction = value ? "已开启；下一次连接变化时切换。" : "已暂停自动切换。"
    log(lastAction)
  }

  func setInterval(_ value: Int) {
    guard Self.intervals.contains(value) else { return }
    interval = value
    defaults.set(value, forKey: "PollSeconds")
    if enabled { scheduleTimer() }
    lastAction = "备用检查间隔已立即更新为 \(value) 秒。"
    log(lastAction)
  }

  private func start() -> Bool {
    do {
      try events.start { [weak self] in self?.scheduleCheck() }
      listening = true
      scheduleTimer()
      return true
    } catch {
      enabled = false
      defaults.set(false, forKey: "Enabled")
      errorMessage = error.localizedDescription
      attention = error.localizedDescription
      lastAction = "监听启动失败，已暂停自动切换。"
      log(error.localizedDescription)
      return false
    }
  }

  /// Stops switching work, preserving the independent wake-settling window.
  private func stop() {
    listening = false
    cancelControl()
    timer?.cancel()
    timer = nil
    pending?.cancel()
    pending = nil
    events.stop()
  }

  func shutdown() {
    stop()
    wakeTask?.cancel()
    wakeTask = nil
    for observer in observers { notificationCenter.removeObserver(observer) }
    observers.removeAll()
  }

  private func scheduleTimer() {
    timer?.cancel()
    timer = scheduler.repeating(every: Double(interval)) { [weak self] in
      guard let self, !self.suspended, self.pending == nil else { return }
      self.scheduleCheck()
    }
  }

  func scheduleCheck() {
    guard enabled, listening, !suspended else { return }
    pending?.cancel()
    pending = scheduler.once(after: 2) { [weak self] in
      guard let self else { return }
      self.pending = nil
      self.check()
    }
  }

  private func baseline() {
    do {
      let connected = try readConnected()
      policy.reset(to: connected)
      displayStatus = connected ? "已连接外接显示器" : "未连接外接显示器"
    } catch {
      policy.reset(to: nil)
      displayStatus = "显示器状态暂不可用"
      log(error.localizedDescription)
    }
  }

  private func check() {
    guard enabled, listening, !suspended else { return }
    do {
      let connected = try readConnected()
      displayStatus = connected ? "已连接外接显示器" : "未连接外接显示器"
      guard let desired = policy.observe(connected, enabled: enabled) else { return }
      cancelControl()
      let id = operationID
      lastAction = "正在更新台前调度设置…"
      let apply = self.apply
      controlTask = Task { @MainActor [weak self] in
        do {
          try Task.checkCancellation()
          let outcome = try await apply(desired)
          guard let self, self.operationID == id else { return }
          self.attention = nil
          self.lastAction =
            outcome == .alreadySet
            ? "台前调度偏好已是目标值，无需重载 Dock。"
            : (desired ? "外接屏断开：已提交开启设置。" : "外接屏连接：已提交关闭设置。")
          self.log(self.lastAction)
          self.controlTask = nil
        } catch is CancellationError {
          // Pausing, sleeping or a newer transition invalidates this operation.
        } catch {
          guard let self, self.operationID == id else { return }
          self.lastAction = "自动切换未完成；可在系统设置中手动调整。"
          self.attention = error.localizedDescription
          self.log(error.localizedDescription)
          self.controlTask = nil
        }
      }
    } catch {
      displayStatus = "显示器状态暂不可用"
      lastAction = "显示器读取失败，等待下一次检查。"
      log(error.localizedDescription)
    }
  }

  private func cancelControl() {
    operationID = UUID()
    controlTask?.cancel()
    controlTask = nil
  }

  func dismissAttention() { attention = nil }

  func refreshLogin() {
    loginEnabled = SMAppService.mainApp.status == .enabled
    loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
  }

  func setLogin(_ value: Bool) {
    do {
      if value {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch { errorMessage = "登录启动设置失败：\(error.localizedDescription)" }
    refreshLogin()
  }

  deinit { shutdown() }

  private func log(_ text: String) { logger.write(text) }
}
