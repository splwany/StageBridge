import Foundation

struct EventLogger {
  let url: URL

  func write(_ text: String) {
    let fm = FileManager.default
    do {
      try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      if let size = try? fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber,
        size.intValue > 512_000
      {
        let previous = url.appendingPathExtension("previous")
        if fm.fileExists(atPath: previous.path) { try fm.removeItem(at: previous) }
        try fm.moveItem(at: url, to: previous)
      }
      if !fm.fileExists(atPath: url.path) { fm.createFile(atPath: url.path, contents: nil) }
      let handle = try FileHandle(forWritingTo: url)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(
        contentsOf: Data("\(ISO8601DateFormatter().string(from: Date())) \(text)\n".utf8))
    } catch { NSLog("StageByScreen log error: %@", error.localizedDescription) }
  }
}
