import Foundation

// MARK: - 对话历史持久化

/// 将 ChatSession 以 JSON 文件形式保存到 Documents/ChatHistory/
/// 每个 session 独立文件，按 UUID 命名
@MainActor
final class ChatHistoryStore: ObservableObject {

    @Published var sessions: [ChatSession] = []

    static let shared = ChatHistoryStore()

    private init() {
        sessions = loadAll()
    }

    // MARK: - 存储路径

    nonisolated private static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("ChatHistory", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    nonisolated private static func filePath(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    // MARK: - 保存

    func save(_ session: ChatSession) {
        // 更新内存
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
        } else {
            sessions.insert(session, at: 0)
        }

        // 写入磁盘
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(session) else { return }
        try? data.write(to: Self.filePath(for: session.id))
    }

    // MARK: - 读取

    nonisolated private func loadAll() -> [ChatSession] {
        let dir = Self.directory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var result: [ChatSession] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let session = try? decoder.decode(ChatSession.self, from: data) else { continue }
            result.append(session)
        }

        return result.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - 删除

    func delete(id: UUID) {
        sessions.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: Self.filePath(for: id))
    }

    /// 刷新列表
    func reload() {
        sessions = loadAll()
    }
}
