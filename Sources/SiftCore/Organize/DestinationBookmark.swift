import Foundation

public struct DestinationBookmark: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let bookmarkData: Data
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        displayName: String,
        bookmarkData: Data,
        createdAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.createdAt = createdAt
    }
}
