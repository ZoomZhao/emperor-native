import Foundation
import OSLog

/// Small local-only diagnostic recorder for release builds. It never uploads
/// data; it keeps a bounded text log in the user's standard Logs directory so
/// startup, parser and save failures can be reported without reproducing them
/// under Xcode.
enum NativeDiagnostics {
    private static let logger = Logger(
        subsystem: "dev.emperor-native.game",
        category: "runtime"
    )
    private static let queue = DispatchQueue(label: "dev.emperor-native.diagnostics")
    private static let maximumBytes = 1_000_000

    static var logURL: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/EmperorNative/EmperorNative.log")
    }

    static func record(_ message: String, error: Error? = nil) {
        let detail = error.map { " · \($0.localizedDescription)" } ?? ""
        logger.info("\(message + detail, privacy: .public)")
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\(detail)\n"
        queue.async {
            guard let url = logURL else { return }
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attributes[.size] as? NSNumber,
                   size.intValue > maximumBytes {
                    try Data(line.utf8).write(to: url, options: .atomic)
                    return
                }
                if !FileManager.default.fileExists(atPath: url.path) {
                    try Data(line.utf8).write(to: url, options: .atomic)
                } else {
                    let handle = try FileHandle(forWritingTo: url)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: Data(line.utf8))
                    try handle.close()
                }
            } catch {
                logger.error("Cannot write local diagnostics: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
