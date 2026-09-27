import Foundation

@main struct CoreChecks {
    static func main() {
        var policy = ConnectionPolicy()
        precondition(policy.observe(false, enabled: true) == nil, "Startup must not toggle")
        precondition(policy.observe(false, enabled: true) == nil, "Manual setting must survive unchanged display state")
        precondition(policy.observe(true, enabled: true) == false, "Connection turns Stage Manager off")
        precondition(policy.observe(true, enabled: true) == nil, "Repeated events must not override manual change")
        precondition(policy.observe(false, enabled: true) == true, "Disconnection turns Stage Manager on")
        precondition(policy.observe(true, enabled: false) == nil, "Paused mode must not apply")
        precondition(policy.observe(true, enabled: true) == nil, "Resume must not replay paused transitions")
        policy.reset(to: nil)
        precondition(policy.observe(true, enabled: true) == nil, "Unknown state must establish a baseline")
        policy.reset(to: false)
        precondition(policy.observe(false, enabled: true) == nil, "Wake baseline must not toggle")
        print("PASS: 9 transition policy checks")
    }
}
