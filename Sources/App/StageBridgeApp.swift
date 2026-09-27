import AppKit
import Carbon
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var monitor: DisplayMonitor!
  private var statusItem: NSStatusItem!
  private var window: NSWindow?
  private var subscription: AnyCancellable?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Keep one instance even when launched from both a DMG and Applications.
    if let id = Bundle.main.bundleIdentifier,
      let other = NSRunningApplication.runningApplications(withBundleIdentifier: id)
        .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })
    {
      other.activate(options: [.activateAllWindows])
      NSApp.terminate(nil)
      return
    }
    monitor = DisplayMonitor()
    let mainMenu = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    add("StageBridge 设置…", #selector(showSettings), ",", to: appMenu)
    appMenu.addItem(.separator())
    add("退出 StageBridge", #selector(quit), "q", to: appMenu)
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)
    NSApp.mainMenu = mainMenu
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = NSImage(
      systemSymbolName: "display.2", accessibilityDescription: "StageBridge")
    subscription = monitor.objectWillChange.sink { [weak self] _ in
      DispatchQueue.main.async { self?.updateMenu() }
    }
    updateMenu()
    let atLogin =
      NSAppleEventManager.shared().currentAppleEvent?
      .paramDescriptor(forKeyword: keyAELaunchedAsLogInItem)?.booleanValue ?? false
    if !atLogin { showSettings() }
  }

  private func updateMenu() {
    let menu = NSMenu()
    let status = NSMenuItem(
      title: monitor.enabled ? "自动切换已开启" : "自动切换已暂停", action: nil, keyEquivalent: "")
    menu.addItem(status)
    if monitor.attention != nil {
      add("⚠︎ 切换遇到问题，查看设置…", #selector(showSettings), "", to: menu)
    }
    menu.addItem(.separator())
    add("设置…", #selector(showSettings), ",", to: menu)
    add(monitor.enabled ? "暂停自动切换" : "开启自动切换", #selector(toggle), "", to: menu)
    menu.addItem(.separator())
    add("退出 StageBridge", #selector(quit), "q", to: menu)
    statusItem.menu = menu
  }

  private func add(_ title: String, _ action: Selector, _ key: String, to menu: NSMenu) {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.target = self
    menu.addItem(item)
  }

  @objc func showSettings() {
    if window == nil {
      let controller = NSHostingController(rootView: SettingsView(monitor: monitor))
      let created = NSWindow(contentViewController: controller)
      created.title = "StageBridge · 台前调度自动切换"
      created.styleMask = [.titled, .closable, .miniaturizable]
      created.standardWindowButton(.zoomButton)?.isHidden = true
      created.isReleasedWhenClosed = false
      created.setContentSize(controller.view.fittingSize)
      created.center()
      window = created
    }
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func toggle() { monitor.setEnabled(!monitor.enabled) }
  @objc private func quit() {
    monitor.shutdown()
    NSApp.terminate(nil)
  }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showSettings()
    return true
  }
  func applicationWillTerminate(_ notification: Notification) { monitor?.shutdown() }
}

@main
struct StageBridgeMain {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
  }
}
