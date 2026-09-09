import Foundation
import Darwin
import HowFriedCore

// This hook never returns instructions or approval decisions. Errors fail open and omit content.
func run() {
    let args = CommandLine.arguments
    guard args.count == 2, let source = Integration(rawValue: args[1]), source != .demo else { return }
    // Bound stdin time and size even if the invoking process does not close the pipe.
    var data = Data()
    let end = ProcessInfo.processInfo.systemUptime + 0.8
    while ProcessInfo.processInfo.systemUptime < end {
        var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        let remaining = Int32(max(1, (end - ProcessInfo.processInfo.systemUptime) * 1000))
        if poll(&descriptor, 1, remaining) <= 0 { return }
        var bytes = [UInt8](repeating: 0, count: 8192)
        let count = read(STDIN_FILENO, &bytes, bytes.count)
        if count <= 0 { break }
        data.append(contentsOf: bytes.prefix(count))
        if data.count > 1_048_576 { return }
    }
    guard let event = PromptAdapter.parse(data, source: source) else { return }
    do {
        let store = try ActivityStore(create: false)
        try store.insert(event)
    } catch {
        // No payload, path, SQLite error string, or prompt content escapes through diagnostics.
        FileHandle.standardError.write(Data("HowFried: observation unavailable; AI work continues.\n".utf8))
    }
}
run()
