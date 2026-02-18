import Foundation

actor DevMatchLogStore {
    static let shared = DevMatchLogStore()

    private var cache: [DevMatchLogEntry]?
    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PickleQuest", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("dev_match_log.json")
    }

    func loadAll() -> [DevMatchLogEntry] {
        if let cache { return cache }
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([DevMatchLogEntry].self, from: data) else {
            cache = []
            return []
        }
        cache = entries
        return entries
    }

    func append(_ entry: DevMatchLogEntry) {
        var entries = loadAll()
        entries.append(entry)
        save(entries)
    }

    func appendBatch(_ batch: [DevMatchLogEntry]) {
        var entries = loadAll()
        entries.append(contentsOf: batch)
        save(entries)
    }

    func clearAll() {
        save([])
    }

    private func save(_ entries: [DevMatchLogEntry]) {
        cache = entries
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
