import Foundation

enum SleepSessionStore {
    private static let fileName = "SleepSessions.json"
    private static let maxSessionCount = 90

    static func loadSessions() -> [SleepSession] {
        let url = storeURL()
        guard let data = try? Data(contentsOf: url) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([SleepSession].self, from: data)
                .sorted { $0.startTime > $1.startTime }
        } catch {
            print("Failed to load sleep sessions: \(error)")
            return []
        }
    }

    static func saveSessions(_ sessions: [SleepSession]) {
        let normalized = Array(
            sessions
                .sorted { $0.startTime > $1.startTime }
                .prefix(maxSessionCount)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            try FileManager.default.createDirectory(at: storeDirectory(), withIntermediateDirectories: true)
            let data = try encoder.encode(normalized)
            try data.write(to: storeURL(), options: [.atomic])
        } catch {
            print("Failed to save sleep sessions: \(error)")
        }
    }

    static func upsert(_ session: SleepSession, into sessions: [SleepSession]) -> [SleepSession] {
        var result = sessions.filter { $0.id != session.id }
        result.insert(session, at: 0)
        result.sort { $0.startTime > $1.startTime }
        return Array(result.prefix(maxSessionCount))
    }

    /// 从会话列表中移除指定会话（例如睡眠时长不足，不生成报告时）。
    static func remove(_ session: SleepSession, from sessions: [SleepSession]) -> [SleepSession] {
        sessions.filter { $0.id != session.id }
    }

    /// 删除指定的录音文件。
    static func deleteRecording(fileName: String) {
        try? FileManager.default.removeItem(at: recordingURL(fileName: fileName))
    }

    static func recordingURL(fileName: String) -> URL {
        recordingDirectory().appendingPathComponent(fileName)
    }

    static func makeRecordingURL(sessionID: UUID) throws -> URL {
        try FileManager.default.createDirectory(at: recordingDirectory(), withIntermediateDirectories: true)
        return recordingURL(fileName: "\(sessionID.uuidString).m4a")
    }

    static func recordingsDirectoryURL() -> URL {
        recordingDirectory()
    }

    static func clearRecordings() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: recordingDirectory(), includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func storeURL() -> URL {
        storeDirectory().appendingPathComponent(fileName)
    }

    private static func storeDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SleepData", isDirectory: true)
    }

    private static func recordingDirectory() -> URL {
        storeDirectory().appendingPathComponent("Recordings", isDirectory: true)
    }
}
