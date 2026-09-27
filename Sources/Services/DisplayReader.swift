import CoreGraphics

enum DisplayReader {
  static func externalConnected() throws -> Bool {
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
      throw MonitorError.message("暂时读不到显示器，跳过本次检查。")
    }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    let capacity = count
    guard CGGetOnlineDisplayList(capacity, &ids, &count) == .success, count > 0, count <= capacity
    else {
      throw MonitorError.message("显示器列表正在变化，跳过本次检查。")
    }
    return ids.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
  }

}
