import Foundation

/// Pure transition policy: never enforce a state while the connection is unchanged.
struct ConnectionPolicy {
  private(set) var baseline: Bool?
  mutating func reset(to connected: Bool?) { baseline = connected }
  mutating func observe(_ connected: Bool, enabled: Bool) -> Bool? {
    defer { baseline = connected }
    guard enabled, let previous = baseline, previous != connected else { return nil }
    return !connected
  }
}
