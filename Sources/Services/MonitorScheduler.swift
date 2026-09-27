import Foundation

protocol ScheduledAction: AnyObject { func cancel() }
protocol MonitorScheduler {
  func once(after seconds: TimeInterval, _ action: @escaping () -> Void) -> ScheduledAction
  func repeating(every seconds: TimeInterval, _ action: @escaping () -> Void) -> ScheduledAction
}

struct MainQueueScheduler: MonitorScheduler {
  func once(after seconds: TimeInterval, _ action: @escaping () -> Void) -> ScheduledAction {
    let item = DispatchWorkItem(block: action)
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    return WorkItemAction(item)
  }

  func repeating(every seconds: TimeInterval, _ action: @escaping () -> Void) -> ScheduledAction {
    let timer = Timer(timeInterval: seconds, repeats: true) { _ in action() }
    timer.tolerance = min(seconds * 0.1, 5)
    RunLoop.main.add(timer, forMode: .common)
    return TimerAction(timer)
  }
}

private final class WorkItemAction: ScheduledAction {
  let item: DispatchWorkItem
  init(_ item: DispatchWorkItem) { self.item = item }
  func cancel() { item.cancel() }
}

private final class TimerAction: ScheduledAction {
  let timer: Timer
  init(_ timer: Timer) { self.timer = timer }
  func cancel() { timer.invalidate() }
  deinit { cancel() }
}
