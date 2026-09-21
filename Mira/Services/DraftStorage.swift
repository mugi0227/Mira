import Foundation

/// Small typed snapshots, atomically replaced. SwiftData schema stays unchanged.
final class DraftStorage {
    struct LoadResult {
        var archive: DraftArchive
        var recoveredCorruption: Bool
    }

    private let fileURL: URL?
    private var memoryData: Data?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL
    }

    static func standard() -> DraftStorage {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mira", isDirectory: true)
        return DraftStorage(fileURL: directory.appendingPathComponent("drafts-v1.json"))
    }

    func load() throws -> LoadResult {
        let data: Data?
        if let fileURL {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return LoadResult(archive: .empty, recoveredCorruption: false)
            }
            data = try Data(contentsOf: fileURL)
        } else {
            data = memoryData
        }
        guard let data else { return LoadResult(archive: .empty, recoveredCorruption: false) }
        do {
            let archive = try JSONDecoder().decode(DraftArchive.self, from: data)
            guard archive.version == 1 else { throw DraftStorageError.unsupportedVersion }
            return LoadResult(archive: archive, recoveredCorruption: false)
        } catch {
            // Keep a recovery copy before a later user edit replaces the broken archive.
            if let fileURL {
                let recoveryURL = fileURL.deletingLastPathComponent()
                    .appendingPathComponent("drafts-recovery-\(UUID().uuidString).json")
                try data.write(to: recoveryURL, options: .atomic)
            }
            return LoadResult(archive: .empty, recoveredCorruption: true)
        }
    }

    func save(_ archive: DraftArchive) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(archive)
        if let fileURL {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } else {
            memoryData = data
        }
    }
}

private enum DraftStorageError: Error {
    case unsupportedVersion
}
