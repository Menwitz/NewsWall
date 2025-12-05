import Foundation

struct Layout: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var rows: Int
    var cols: Int
    var channelIDs: [UUID]  // Ordered list of channel IDs for this layout
    var createdAt: Date
    var lastUsed: Date?
    
    init(id: UUID = UUID(), name: String, rows: Int, cols: Int, channelIDs: [UUID] = [], createdAt: Date = Date(), lastUsed: Date? = nil) {
        self.id = id
        self.name = name
        self.rows = rows
        self.cols = cols
        self.channelIDs = channelIDs
        self.createdAt = createdAt
        self.lastUsed = lastUsed
    }
}
