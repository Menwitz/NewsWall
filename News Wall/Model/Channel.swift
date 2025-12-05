import Foundation

struct Channel: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var url: URL
    var enabled: Bool
    var group: String = "All"


    init(id: UUID = UUID(), title: String, url: URL, enabled: Bool = true, group: String = "All") {
        self.id = id
        self.title = title
        self.url = url
        self.enabled = enabled
        self.group = group
    }

    enum CodingKeys: String, CodingKey { case id, title, url, enabled, group }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id      = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title   = try c.decode(String.self, forKey: .title)
        self.url     = try c.decode(URL.self, forKey: .url)
        self.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.group   = try c.decodeIfPresent(String.self, forKey: .group) ?? "All"
    }
}
