import AppKit
import CoreGraphics
import ServiceManagement

private let displayCallback: CGDisplayReconfigurationCallBack = { _, flags, context in
    guard !flags.contains(.beginConfigurationFlag), let context else { return }
    let monitor = Unmanaged<DisplayMonitor>.fromOpaque(context).takeUnretainedValue()
    DispatchQueue.main.async { monitor.scheduleCheck() }
}

final class DisplayMonitor: ObservableObject {
    static let intervals = [15, 30, 60, 120, 300]
    @Published private(set) var enabled = false
    @Published private(set) var interval = 60
    @Published private(set) var displayStatus = "读取显示器状态…"
    @Published private(set) var lastAction = "启动时只记录连接状态。"
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginNeedsApproval = false
    @Published var errorMessage: String?
    @Published private(set) var hasLegacy = false
    private var policy = ConnectionPolicy()
    private var timer: Timer?
    private var pending: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    private var registered = false
    private var systemAsleep = false
    private var screenAsleep = false
    private var settling = false
    private var suspended: Bool { systemAsleep || screenAsleep || settling }
    private let defaults = UserDefaults.standard
    let logURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/StageBridge/events.log")
    private var legacyPlist: URL { FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/com.local.stage-manager-display-watch.plist") }

    init() {
        interval = defaults.integer(forKey: "PollSeconds")
        if !Self.intervals.contains(interval) { interval = 60 }
        enabled = defaults.bool(forKey: "Enabled")
        hasLegacy = FileManager.default.fileExists(atPath: legacyPlist.path)
            && !defaults.bool(forKey: "LegacyMigrated")
        if hasLegacy { enabled = false }
        refreshLogin()
        baseline()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self else { return }
                if note.name == NSWorkspace.willSleepNotification { self.systemAsleep = true }
                else { self.screenAsleep = true }
                self.pending?.cancel()
                self.pending = nil
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self else { return }
                if note.name == NSWorkspace.didWakeNotification { self.systemAsleep = false }
                else { self.screenAsleep = false }
                self.settling = true
                self.pending?.cancel()
                let job = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.pending = nil
                    self.settling = false
                    if !self.systemAsleep && !self.screenAsleep { self.baseline() }
                }
                self.pending = job
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: job)
            })
        }
        if enabled { start() }
        log("App started; enabled=\(enabled); interval=\(interval)")
    }

    func setEnabled(_ value: Bool) {
        guard !hasLegacy else { errorMessage = "请先迁移旧版监听器，避免两个版本同时控制台前调度。"; return }
        stop()
        settling = false
        enabled = value
        defaults.set(value, forKey: "Enabled")
        baseline()
        if value { start() }
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

    private func start() {
        guard !registered else { return }
        let result = CGDisplayRegisterReconfigurationCallback(displayCallback, Unmanaged.passUnretained(self).toOpaque())
        guard result == .success else {
            enabled = false
            defaults.set(false, forKey: "Enabled")
            errorMessage = "无法监听显示器变化（\(result.rawValue)）。"
            return
        }
        registered = true
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        pending?.cancel(); pending = nil
        if registered {
            CGDisplayRemoveReconfigurationCallback(displayCallback, Unmanaged.passUnretained(self).toOpaque())
            registered = false
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Double(interval), repeats: true) { [weak self] _ in
            guard let self, !self.suspended, self.pending == nil else { return }
            self.scheduleCheck()
        }
        timer?.tolerance = min(Double(interval) * 0.1, 5)
    }

    func scheduleCheck() {
        guard enabled, !suspended else { return }
        pending?.cancel()
        let job = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pending = nil
            self.check()
        }
        pending = job
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: job)
    }

    private func externalConnected() throws -> Bool {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
            throw MonitorError.message("暂时读不到显示器，跳过本次检查。")
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        let capacity = count
        guard CGGetOnlineDisplayList(capacity, &ids, &count) == .success else {
            throw MonitorError.message("显示器列表正在变化，跳过本次检查。")
        }
        return ids.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
    }

    private func baseline() {
        do {
            let connected = try externalConnected()
            policy.reset(to: connected)
            displayStatus = connected ? "已连接外接显示器" : "未连接外接显示器"
        } catch {
            policy.reset(to: nil)
            displayStatus = "显示器状态暂不可用"
            log(error.localizedDescription)
        }
    }

    private func check() {
        guard enabled, !suspended else { return }
        do {
            let connected = try externalConnected()
            displayStatus = connected ? "已连接外接显示器" : "未连接外接显示器"
            guard let desired = policy.observe(connected, enabled: enabled) else { return }
            try StageManagerControl.apply(desired)
            lastAction = desired ? "外接屏断开：已开启台前调度。" : "外接屏连接：已关闭台前调度。"
            log(lastAction)
        } catch {
            lastAction = "本次自动切换未完成。"
            errorMessage = error.localizedDescription
            log(error.localizedDescription)
        }
    }

    func refreshLogin() {
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func setLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { errorMessage = "登录启动设置失败：\(error.localizedDescription)" }
        refreshLogin()
    }

    /// Explicit one-time migration. Legacy files are archived for recovery.
    func migrateLegacy() {
        do {
            let target = "gui/\(getuid())/com.local.stage-manager-display-watch"
            let loaded = try ProcessRunner.run("/bin/launchctl", ["print", target]).0 == 0
            if loaded {
                guard try ProcessRunner.run("/bin/launchctl", ["bootout", target]).0 == 0 else {
                    throw MonitorError.message("无法停止旧版监听器，请先在旧版 App 中暂停。")
                }
            }
            guard try ProcessRunner.run("/bin/launchctl", ["disable", target]).0 == 0 else {
                throw MonitorError.message("无法禁用旧版登录项，迁移已暂停。")
            }
            let backup = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/StageBridge/LegacyBackup-\(Int(Date().timeIntervalSince1970))")
            try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
            for name in ["com.local.stage-manager-display-watch.plist", "stage-manager-display-watch.py"] {
                let old = legacyPlist.deletingLastPathComponent().appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: old.path) {
                    try FileManager.default.moveItem(at: old, to: backup.appendingPathComponent(name))
                }
            }
            let legacy = UserDefaults(suiteName: "com.local.stage-manager-display-watch")
            let previous = legacy?.integer(forKey: "PollSeconds") ?? 60
            defaults.set(true, forKey: "LegacyMigrated")
            hasLegacy = false
            setInterval(Self.intervals.contains(previous) ? previous : 60)
            setEnabled(legacy?.object(forKey: "Enabled") as? Bool ?? true)
            lastAction = "旧版已停用并备份；设置已迁移。"
            log(lastAction)
        } catch { errorMessage = error.localizedDescription; log(error.localizedDescription) }
    }

    func log(_ text: String) {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let size = try? fm.attributesOfItem(atPath: logURL.path)[.size] as? NSNumber,
               size.intValue > 512_000 {
                let previous = logURL.appendingPathExtension("previous")
                if fm.fileExists(atPath: previous.path) { try fm.removeItem(at: previous) }
                try fm.moveItem(at: logURL, to: previous)
            }
            if !fm.fileExists(atPath: logURL.path) { fm.createFile(atPath: logURL.path, contents: nil) }
            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data("\(ISO8601DateFormatter().string(from: Date())) \(text)\n".utf8))
        } catch { NSLog("StageBridge log error: %@", error.localizedDescription) }
    }
}

enum MonitorError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

enum ProcessRunner {
    static func run(_ executable: String, _ arguments: [String]) throws -> (Int32, String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try task.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (task.terminationStatus, String(data: output, encoding: .utf8) ?? "")
    }
}

enum StageManagerControl {
    /// Experimental compatibility backend, NOT a documented Stage Manager API.
    static func apply(_ enabled: Bool) throws {
        let domain = "com.apple.WindowManager" as CFString
        let key = "GloballyEnabled" as CFString
        CFPreferencesAppSynchronize(domain)
        if let current = CFPreferencesCopyAppValue(key, domain) as? NSNumber,
           current.boolValue == enabled { return }
        CFPreferencesSetAppValue(key, enabled ? kCFBooleanTrue : kCFBooleanFalse, domain)
        guard CFPreferencesAppSynchronize(domain) else {
            throw MonitorError.message("无法保存台前调度偏好；请暂停自动切换后检查系统设置。")
        }
        guard let readback = CFPreferencesCopyAppValue(key, domain) as? NSNumber,
              readback.boolValue == enabled else {
            throw MonitorError.message("台前调度偏好回读不一致。")
        }
        // The undocumented preference currently requires Dock to reload.
        let result = try ProcessRunner.run("/usr/bin/killall", ["Dock"])
        guard result.0 == 0 else { throw MonitorError.message("偏好已保存，但 Dock 未能重新载入。") }
    }
}
