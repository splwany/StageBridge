import Foundation

/// Executes short system utilities off the main thread with bounded execution time.
/// File-backed output avoids pipe-buffer deadlocks when a utility emits diagnostics.
enum ProcessRunner {
  static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 5)
    async throws -> (Int32, String)
  {
    let execution = ProcessExecution()
    return try await withTaskCancellationHandler(
      operation: {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
          DispatchQueue.global(qos: .utility).async {
            continuation.resume(
              with: Result {
                try execution.run(executable, arguments, timeout: timeout)
              })
          }
        }
      }, onCancel: { execution.cancel() })
  }
}

private final class ProcessExecution: @unchecked Sendable {
  private let lock = NSLock()
  private var process: Process?
  private var cancelled = false

  func cancel() {
    lock.lock()
    cancelled = true
    if let process, process.isRunning { kill(process.processIdentifier, SIGKILL) }
    lock.unlock()
  }

  func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) throws -> (
    Int32, String
  ) {
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    guard
      FileManager.default.createFile(
        atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
    else {
      throw MonitorError.message("无法创建命令诊断文件。")
    }
    defer { try? FileManager.default.removeItem(at: outputURL) }
    let output = try FileHandle(forWritingTo: outputURL)
    defer { try? output.close() }
    let task = Process()
    task.executableURL = URL(fileURLWithPath: executable)
    task.arguments = arguments
    task.standardOutput = output
    task.standardError = output
    task.standardInput = FileHandle.nullDevice
    let finished = DispatchSemaphore(value: 0)
    task.terminationHandler = { _ in finished.signal() }
    lock.lock()
    if cancelled {
      lock.unlock()
      throw CancellationError()
    }
    do {
      try task.run()
      process = task
      lock.unlock()
    } catch {
      lock.unlock()
      throw error
    }
    let timedOut = finished.wait(timeout: .now() + timeout) == .timedOut
    lock.lock()
    if timedOut && task.isRunning { kill(task.processIdentifier, SIGKILL) }
    let wasCancelled = cancelled
    process = nil
    lock.unlock()
    if wasCancelled { throw CancellationError() }
    if timedOut {
      throw MonitorError.message("系统命令执行超时：\(URL(fileURLWithPath: executable).lastPathComponent)。")
    }
    let reader = try FileHandle(forReadingFrom: outputURL)
    defer { try? reader.close() }
    let data = try reader.read(upToCount: 16_384) ?? Data()
    return (
      task.terminationStatus,
      String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }
}
