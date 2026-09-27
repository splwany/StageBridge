import CoreFoundation
import Foundation

enum StageManagerOutcome { case alreadySet, updated }

protocol StageManagerPreferences {
  func synchronize() -> Bool
  func read() -> Bool?
  func write(_ enabled: Bool)
}

struct SystemStageManagerPreferences: StageManagerPreferences {
  private let domain = "com.apple.WindowManager" as CFString
  private let key = "GloballyEnabled" as CFString
  func synchronize() -> Bool { CFPreferencesAppSynchronize(domain) }
  func read() -> Bool? { (CFPreferencesCopyAppValue(key, domain) as? NSNumber)?.boolValue }
  func write(_ enabled: Bool) {
    CFPreferencesSetAppValue(key, enabled ? kCFBooleanTrue : kCFBooleanFalse, domain)
  }
}

enum StageManagerControl {
  /// Experimental compatibility backend, NOT a documented Stage Manager API.
  /// A successful result confirms preferences and command completion, not the visible UI.
  @MainActor static func apply(
    _ enabled: Bool,
    preferences: StageManagerPreferences = SystemStageManagerPreferences(),
    reloadDock: () async throws -> (Int32, String) = {
      try await ProcessRunner.run("/usr/bin/killall", ["Dock"])
    }
  ) async throws -> StageManagerOutcome {
    try Task.checkCancellation()
    guard preferences.synchronize(), let current = preferences.read() else {
      throw MonitorError.message("无法读取台前调度设置。请确认系统支持台前调度，并在系统设置中手动调整。")
    }
    if current == enabled { return .alreadySet }
    preferences.write(enabled)
    guard preferences.synchronize() else {
      throw MonitorError.message("无法保存台前调度偏好；请在系统设置中手动调整。")
    }
    guard preferences.read() == enabled else {
      throw MonitorError.message("台前调度偏好回读不一致；本次不重载 Dock。")
    }
    do {
      let result = try await reloadDock()
      guard result.0 == 0 else {
        throw MonitorError.message(result.1.isEmpty ? "命令返回 \(result.0)" : result.1)
      }
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw MonitorError.message("偏好已保存，但 Dock 未能重新载入。\(error.localizedDescription)")
    }
    return .updated
  }
}
