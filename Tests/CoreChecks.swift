import Foundation

@main struct CoreChecks {
  static func main() async throws {
    var policy = ConnectionPolicy()
    precondition(policy.observe(false, enabled: true) == nil, "Startup must not toggle")
    precondition(
      policy.observe(false, enabled: true) == nil,
      "Manual setting must survive unchanged display state")
    precondition(policy.observe(true, enabled: true) == false, "Connection turns Stage Manager off")
    precondition(
      policy.observe(true, enabled: true) == nil, "Repeated events must not override manual change")
    precondition(
      policy.observe(false, enabled: true) == true, "Disconnection turns Stage Manager on")
    precondition(policy.observe(true, enabled: false) == nil, "Paused mode must not apply")
    precondition(
      policy.observe(true, enabled: true) == nil, "Resume must not replay paused transitions")
    policy.reset(to: nil)
    precondition(
      policy.observe(true, enabled: true) == nil, "Unknown state must establish a baseline")
    policy.reset(to: false)
    precondition(policy.observe(false, enabled: true) == nil, "Wake baseline must not toggle")
    var lifecycle = MonitorLifecycle()
    lifecycle.sleep(screen: false)
    lifecycle.sleep(screen: true)
    lifecycle.wake(screen: false)
    precondition(lifecycle.suspended, "System wake must not bypass screen sleep")
    precondition(!lifecycle.finishSettling(), "Sleeping screen cannot establish a baseline")
    lifecycle.wake(screen: true)
    precondition(lifecycle.suspended, "Wake must retain settling protection")
    precondition(
      lifecycle.finishSettling() && !lifecycle.suspended, "Settled wake resumes monitoring")
    lifecycle.wake(screen: true)
    lifecycle.sleep(screen: true)
    precondition(!lifecycle.finishSettling(), "Another sleep invalidates a pending wake")

    let output = try await ProcessRunner.run("/bin/sh", ["-c", "printf diagnostic >&2; exit 7"])
    precondition(output.0 == 7 && output.1 == "diagnostic", "Preserve command failure diagnostics")
    let large = try await ProcessRunner.run("/bin/sh", ["-c", "head -c 100000 /dev/zero"])
    precondition(
      large.0 == 0 && large.1.utf8.count == 16_384,
      "Large output must not deadlock or flood diagnostics")
    let started = Date()
    do {
      _ = try await ProcessRunner.run("/bin/sleep", ["10"], timeout: 0.1)
      preconditionFailure("Timeout must fail")
    } catch is MonitorError {}
    precondition(Date().timeIntervalSince(started) < 3, "Timeout must bound execution")
    let cancelled = Task { try await ProcessRunner.run("/bin/sleep", ["10"]) }
    try await Task.sleep(nanoseconds: 100_000_000)
    cancelled.cancel()
    do {
      _ = try await cancelled.value
      preconditionFailure("Cancellation must fail")
    } catch is CancellationError {}
    do {
      _ = try await ProcessRunner.run("/nonexistent/stagebyscreen-command", [])
      preconditionFailure("Missing command must throw")
    } catch {}

    print(
      "PASS: transition, sleep/wake, process diagnostics, timeout, cancellation checks"
    )
  }

}
