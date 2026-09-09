import Foundation

/// Opt-in local scanning. Paths are used only in memory; checkpoints use hashed identities.
public final class UsageScanner {
    private let store: ActivityStore
    private let root: URL
    public init(store: ActivityStore, root: URL) { self.store = store; self.root = root }
    public func baseline(now: Date) throws {
        for url in files() {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            try store.setValue(checkpoint(url), String(size), now: now)
        }
    }
    private func checkpoint(_ url: URL) -> String { "offset:" + privateID(url.path) }
    private func files() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) else { return [] }
        return enumerator.compactMap { $0 as? URL }.filter {
            guard $0.pathExtension == "jsonl", let values = try? $0.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else { return false }
            return values.isRegularFile == true && values.isSymbolicLink != true
        }
    }
    public func scan(since: Date, now: Date = Date()) throws {
        for url in files() {
            let key = checkpoint(url)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            var offset = UInt64(try store.value(key) ?? "0") ?? 0
            let discardKey = "discard:" + privateID(url.path)
            var discarding = try store.value(discardKey) == "1"
            if offset > size { offset = 0; discarding = false; try store.setValue(discardKey, "0", now: now) }
            guard offset < size else { continue }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            try handle.seek(toOffset: offset)
            let data = try handle.read(upToCount: 4_194_304) ?? Data()
            guard let lastNewline = data.lastIndex(of: 10) else {
                // Preserve ordinary partial records. Skip oversized records in bounded chunks,
                // retaining the discard flag so their tails cannot be mistaken for new records.
                if data.count == 4_194_304 || discarding {
                    try store.setValue(discardKey, "1", now: now)
                    try store.setValue(key, String(offset + UInt64(data.count)), now: now)
                }
                continue
            }
            let start = discarding ? (data.firstIndex(of: 10)! + 1) : 0
            for line in data[start..<(lastNewline + 1)].split(separator: 10) {
                if let usage = ClaudeUsageAdapter.parse(Data(line)), usage.timestamp >= since, usage.timestamp <= now.addingTimeInterval(5) {
                    try store.ingestUsage(usage, now: now)
                }
            }
            offset += UInt64(lastNewline + 1)
            if discarding { try store.setValue(discardKey, "0", now: now) }
            try store.setValue(key, String(offset), now: now)
        }
    }
}
