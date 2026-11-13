import Foundation

/// A topic kept by the Sky service: a title, a short summary for its card,
/// and whether it is still open.
public struct SkyThread: Decodable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    /// Markdown.
    public var summary: String
    public var createdAt: Date
    /// When the thread was created, last given a message, or last edited.
    public var updatedAt: Date
    /// Nil while the thread is open.
    public var resolvedAt: Date?

    public var isResolved: Bool { resolvedAt != nil }

    public init(id: String, title: String, summary: String, createdAt: Date, updatedAt: Date, resolvedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.resolvedAt = resolvedAt
    }

    /// One entry in a thread.
    public struct Message: Decodable, Equatable, Identifiable, Sendable {
        public var id: String
        public var createdAt: Date
        /// Markdown. Links and images use markdown syntax.
        public var body: String

        public init(id: String, createdAt: Date, body: String) {
            self.id = id
            self.createdAt = createdAt
            self.body = body
        }
    }
}

/// A thread together with its messages, oldest first.
public struct SkyThreadDetail: Decodable, Equatable, Sendable {
    public var thread: SkyThread
    public var messages: [SkyThread.Message]

    public init(thread: SkyThread, messages: [SkyThread.Message]) {
        self.thread = thread
        self.messages = messages
    }

    private enum CodingKeys: String, CodingKey { case messages }

    /// The service sends the thread's fields and `messages` side by side in one object.
    public init(from decoder: any Decoder) throws {
        thread = try SkyThread(from: decoder)
        messages = try decoder.container(keyedBy: CodingKeys.self).decode([SkyThread.Message].self, forKey: .messages)
    }
}
