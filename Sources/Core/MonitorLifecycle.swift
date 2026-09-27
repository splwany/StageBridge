import Foundation

/// Sleep and wake settling are independent of whether automatic switching is enabled.
struct MonitorLifecycle {
  private(set) var systemAsleep = false
  private(set) var screenAsleep = false
  private(set) var settling = false
  var suspended: Bool { systemAsleep || screenAsleep || settling }

  mutating func sleep(screen: Bool) {
    if screen { screenAsleep = true } else { systemAsleep = true }
  }

  mutating func wake(screen: Bool) {
    if screen { screenAsleep = false } else { systemAsleep = false }
    settling = true
  }

  mutating func finishSettling() -> Bool {
    settling = false
    return !systemAsleep && !screenAsleep
  }
}
