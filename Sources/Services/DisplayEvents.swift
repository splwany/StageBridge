import CoreGraphics
import Foundation

protocol DisplayEventSource: AnyObject {
  func start(_ onChange: @escaping () -> Void) throws
  func stop()
}

/// Owns the CoreGraphics callback registration for exactly one monitoring session.
final class DisplayEvents: DisplayEventSource {
  private var registered = false
  private var onChange: (() -> Void)?
  private static let callback: CGDisplayReconfigurationCallBack = { _, flags, context in
    guard !flags.contains(.beginConfigurationFlag), let context else { return }
    let source = Unmanaged<DisplayEvents>.fromOpaque(context).takeUnretainedValue()
    DispatchQueue.main.async { [weak source] in source?.onChange?() }
  }

  func start(_ onChange: @escaping () -> Void) throws {
    stop()
    self.onChange = onChange
    let result = CGDisplayRegisterReconfigurationCallback(
      Self.callback, Unmanaged.passUnretained(self).toOpaque())
    guard result == .success else {
      self.onChange = nil
      throw MonitorError.message("无法监听显示器变化（\(result.rawValue)）。")
    }
    registered = true
  }

  func stop() {
    onChange = nil
    if registered {
      CGDisplayRemoveReconfigurationCallback(
        Self.callback, Unmanaged.passUnretained(self).toOpaque())
      registered = false
    }
  }

  deinit { stop() }
}
