import AppKit

private final class TestEvents: DisplayEventSource {
  var callback: (() -> Void)?
  var fail = false
  func start(_ onChange: @escaping () -> Void) throws {
    if fail { throw MonitorError.message("Test registration failure") }
    callback = onChange
  }
  func stop() { callback = nil }
}

private final class TestScheduler: MonitorScheduler {
  final class Action: ScheduledAction {
    let delay: Double
    let repeats: Bool
    let body: () -> Void
    var cancelled = false
    init(_ delay: Double, repeats: Bool, body: @escaping () -> Void) {
      self.delay = delay
      self.repeats = repeats
      self.body = body
    }
    func cancel() { cancelled = true }
    func fire() {
      if !cancelled {
        if !repeats { cancelled = true }
        body()
      }
    }
  }
  var actions: [Action] = []
  func once(after seconds: TimeInterval, _ action: @escaping () -> Void) -> ScheduledAction {
    let job = Action(seconds, repeats: false, body: action)
    actions.append(job)
    return job
  }
  func repeating(every seconds: TimeInterval, _ action: @escaping () -> Void) -> ScheduledAction {
    let job = Action(seconds, repeats: true, body: action)
    actions.append(job)
    return job
  }
  func fire(_ delay: Double) {
    let due = actions.filter { $0.delay == delay && !$0.cancelled }
    for action in due { action.fire() }
  }
  var pendingCount: Int { actions.filter { !$0.cancelled && !$0.repeats }.count }
}

@main struct MonitorChecks {
  @MainActor static func main() async throws {
    let suite = "StageByScreenMonitorTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
    defer {
      defaults.removePersistentDomain(forName: suite)
      try? FileManager.default.removeItem(at: home)
    }
    let events = TestEvents()
    let clock = TestScheduler()
    let center = NotificationCenter()
    var connected = false
    var readFails = false
    var applied: [Bool] = []
    var controlFails = false
    var holdControl = false
    var completion: CheckedContinuation<StageManagerOutcome, Error>?
    let monitor = DisplayMonitor(
      defaults: defaults, events: events, scheduler: clock,
      readConnected: {
        if readFails { throw MonitorError.message("Unavailable") }
        return connected
      },
      apply: {
        applied.append($0)
        if controlFails { throw MonitorError.message("Test backend failure") }
        if holdControl { return try await withCheckedThrowingContinuation { completion = $0 } }
        return .updated
      }, notificationCenter: center, home: home)
    defer { monitor.shutdown() }
    precondition(monitor.interval == 300, "New installation defaults to five minutes")
    monitor.setEnabled(true)
    precondition(applied.isEmpty, "Enabling only establishes baseline")
    connected = true
    events.callback?()
    events.callback?()
    precondition(clock.pendingCount == 1, "Display storms must debounce to one job")
    monitor.setInterval(600)
    precondition(defaults.integer(forKey: "PollSeconds") == 600, "Minute selection persists seconds")
    precondition(clock.pendingCount == 1, "Interval change preserves display work")
    clock.fire(2)
    await settleTasks(monitor)
    precondition(applied == [false], "Connection submits exactly one disable")
    clock.fire(600)
    clock.fire(2)
    await settleTasks(monitor)
    precondition(applied == [false], "Polling never reapplies unchanged state")
    connected = false
    events.callback?()
    monitor.setEnabled(false)
    clock.fire(2)
    await settleTasks(monitor)
    precondition(applied == [false], "Pause cancels queued work")
    monitor.setEnabled(true)
    precondition(applied == [false], "Resume never replays paused transition")

    center.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
    connected = true
    center.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
    monitor.setEnabled(false)
    monitor.setEnabled(true)
    events.callback?()
    precondition(clock.pendingCount == 1, "Toggle during wake retains only the wake baseline job")
    clock.fire(3)
    events.callback?()
    clock.fire(2)
    await settleTasks(monitor)
    precondition(applied == [false], "Sleep-time plug must only establish baseline")
    connected = false
    events.callback?()
    clock.fire(2)
    await settleTasks(monitor)
    precondition(applied == [false, true], "Next awake transition still works")

    controlFails = true
    connected = true
    events.callback?()
    clock.fire(2)
    await settleTasks(monitor)
    precondition(
      monitor.attention != nil && monitor.errorMessage == nil,
      "Background failure remains visible without a modal")
    let attempts = applied.count
    clock.fire(600)
    clock.fire(2)
    await settleTasks(monitor)
    precondition(applied.count == attempts, "Failed control must not retry unchanged state")
    controlFails = false
    holdControl = true
    connected = false
    events.callback?()
    clock.fire(2)
    let deadline = Date().addingTimeInterval(2)
    while completion == nil && Date() < deadline { try await Task.sleep(nanoseconds: 1_000_000) }
    precondition(completion != nil, "Delayed backend must start")
    monitor.setEnabled(false)
    completion?.resume(returning: .updated)
    for _ in 0..<10 { await Task.yield() }
    precondition(monitor.lastAction == "已暂停自动切换。", "Stale completion cannot overwrite pause status")
    holdControl = false
    monitor.setEnabled(true)

    readFails = true
    events.callback?()
    clock.fire(2)
    precondition(monitor.displayStatus == "显示器状态暂不可用")
    precondition(
      monitor.errorMessage == nil, "Transient read failures must not show recurring modal alerts")
    readFails = false
    events.fail = true
    monitor.setEnabled(false)
    monitor.setEnabled(true)
    precondition(!monitor.enabled && !defaults.bool(forKey: "Enabled"))
    precondition(
      monitor.lastAction.contains("失败"), "Startup failure must not be overwritten with success")
    try await backendChecks()
    print(
      "PASS: monitor debounce, interval, pause/resume, wake toggling, transient failure and registration failure checks"
    )
  }

  private final class Preferences: StageManagerPreferences {
    var value: Bool? = false
    var syncOK = true
    var ignoreWrites = false
    func synchronize() -> Bool { syncOK }
    func read() -> Bool? { value }
    func write(_ enabled: Bool) { if !ignoreWrites { value = enabled } }
  }

  @MainActor static func backendChecks() async throws {
    let preferences = Preferences()
    var reloads = 0
    let reload: () async throws -> (Int32, String) = {
      reloads += 1
      return (0, "")
    }
    let unchanged = try await StageManagerControl.apply(
      false, preferences: preferences, reloadDock: reload)
    precondition(
      unchanged == .alreadySet && reloads == 0, "Matching preference must not restart Dock")
    let changed = try await StageManagerControl.apply(
      true, preferences: preferences, reloadDock: reload)
    precondition(changed == .updated && reloads == 1 && preferences.value == true)
    preferences.ignoreWrites = true
    do {
      _ = try await StageManagerControl.apply(false, preferences: preferences, reloadDock: reload)
      preconditionFailure("Readback mismatch must fail")
    } catch is MonitorError {}
    precondition(reloads == 1, "Failed readback must not restart Dock")
    preferences.ignoreWrites = false
    do {
      _ = try await StageManagerControl.apply(
        false, preferences: preferences, reloadDock: { (1, "Denied") })
      preconditionFailure("Dock failure must surface partial success")
    } catch { precondition(error.localizedDescription.contains("偏好已保存")) }
    preferences.value = nil
    do {
      _ = try await StageManagerControl.apply(true, preferences: preferences, reloadDock: reload)
      preconditionFailure("Unknown backend must fail without creating preferences")
    } catch is MonitorError {}
    precondition(preferences.value == nil && reloads == 1)
    print(
      "PASS: Stage Manager unchanged, write/readback, partial failure and unavailable backend checks"
    )
  }

  @MainActor static func settleTasks(_ monitor: DisplayMonitor) async {
    let deadline = Date().addingTimeInterval(2)
    while monitor.lastAction == "正在更新台前调度设置…" && Date() < deadline {
      try? await Task.sleep(nanoseconds: 1_000_000)
    }
    precondition(monitor.lastAction != "正在更新台前调度设置…", "Control task must finish")
  }
}
