import Foundation

enum CacheService {
    static func cacheSize() -> Int64 {
        [FileManager.default.temporaryDirectory, cachesDirectory, SleepSessionStore.recordingsDirectoryURL()].reduce(0) { total, url in
            total + folderSize(url)
        }
    }

    static func clearCache() {
        [FileManager.default.temporaryDirectory, cachesDirectory].forEach { url in
            guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return }
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    static func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    private static func folderSize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var size: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            size += Int64(values?.fileSize ?? 0)
        }
        return size
    }
}
