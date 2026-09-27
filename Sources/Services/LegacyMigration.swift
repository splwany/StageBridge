import Foundation

/// An interrupted archive resumes at the same location on the next launch.
/// The progress marker is recorded before any original file is moved.
final class LegacyMigration {
  struct Settings {
    let enabled: Bool
    let interval: Int
  }
  private let defaults: UserDefaults
  private let home: URL
  private let fm = FileManager.default
  private let label = "com.local.stage-manager-display-watch"
  private let progressKey = "LegacyBackupInProgress"

  init(
    defaults: UserDefaults = .standard, home: URL = FileManager.default.homeDirectoryForCurrentUser
  ) {
    self.defaults = defaults
    self.home = home
  }

  var isNeeded: Bool {
    if defaults.string(forKey: progressKey) != nil { return true }
    return !defaults.bool(forKey: "LegacyMigrated")
      && fm.fileExists(atPath: agentDirectory.appendingPathComponent(label + ".plist").path)
  }

  private var agentDirectory: URL { home.appendingPathComponent("Library/LaunchAgents") }

  @MainActor func perform() async throws -> Settings {
    let target = "gui/\(getuid())/\(label)"
    let loaded = try await ProcessRunner.run("/bin/launchctl", ["print", target]).0 == 0
    if loaded { try await command(["bootout", target], failure: "无法停止旧版监听器。") }
    try await command(["disable", target], failure: "无法禁用旧版登录项。")
    try archiveFiles()
    let legacy = UserDefaults(suiteName: label)
    let result = Settings(
      enabled: legacy?.object(forKey: "Enabled") as? Bool ?? true,
      interval: legacy?.object(forKey: "PollSeconds") as? Int ?? 60)
    // Import before clearing the journal so interruption cannot lose the old settings.
    defaults.set(result.enabled, forKey: "Enabled")
    defaults.set(result.interval, forKey: "PollSeconds")
    defaults.set(true, forKey: "LegacyMigrated")
    defaults.removeObject(forKey: progressKey)
    return result
  }

  func archiveFiles() throws {
    let backup =
      defaults.string(forKey: progressKey).map { URL(fileURLWithPath: $0) }
      ?? home.appendingPathComponent(
        "Library/Application Support/StageBridge/LegacyBackup-\(UUID().uuidString)")
    defaults.set(backup.path, forKey: progressKey)
    try fm.createDirectory(at: backup, withIntermediateDirectories: true)
    for name in [label + ".plist", "stage-manager-display-watch.py"] {
      let source = agentDirectory.appendingPathComponent(name)
      if fm.fileExists(atPath: source.path) {
        // Never overwrite a backup if a legacy app recreated its file during migration.
        try fm.moveItem(at: source, to: backup.appendingPathComponent(name))
      }
    }
  }

  private func command(_ arguments: [String], failure: String) async throws {
    let result = try await ProcessRunner.run("/bin/launchctl", arguments)
    guard result.0 == 0 else { throw MonitorError.message("\(failure) \(result.1)") }
  }
}
