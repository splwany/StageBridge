import Combine
import Foundation
import Sparkle

/// Sparkle owns download progress, signature validation, installation and relaunch.
final class SoftwareUpdater: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
  @Published private(set) var availableVersion: String?
  @Published private(set) var canCheckForUpdates = false
  @Published private(set) var automaticallyChecksForUpdates = true
  private var controller: SPUStandardUpdaterController!

  override init() {
    super.init()
    controller = SPUStandardUpdaterController(
      startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self)
    controller.updater.publisher(for: \.canCheckForUpdates)
      .assign(to: &$canCheckForUpdates)
    controller.updater.publisher(for: \.automaticallyChecksForUpdates)
      .assign(to: &$automaticallyChecksForUpdates)
    controller.startUpdater()
  }

  func checkForUpdates() { controller.checkForUpdates(nil) }

  func setAutomaticChecks(_ value: Bool) {
    controller.updater.automaticallyChecksForUpdates = value
  }

  var supportsGentleScheduledUpdateReminders: Bool { true }

  func standardUserDriverShouldHandleShowingScheduledUpdate(
    _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
  ) -> Bool {
    // Background checks expose an update button without interrupting other apps.
    false
  }

  func standardUserDriverWillHandleShowingUpdate(
    _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
  ) {
    availableVersion = update.displayVersionString
  }

  func standardUserDriverWillFinishUpdateSession() { availableVersion = nil }
}
