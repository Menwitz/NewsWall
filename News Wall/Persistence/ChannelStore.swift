import Foundation

final class ChannelStore {
    private(set) var channels: [Channel] = []
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    let fileURL: URL

    init(appName: String = "NewsWall") throws {
        let appSupport = try FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = appSupport.appendingPathComponent(appName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("channels.json")
        try loadOrSeed()
    }

    func save() throws {
        let data = try encoder.encode(channels)
        try data.write(to: fileURL, options: [.atomic])
    }

    func set(_ new: [Channel]) throws { channels = new; try save() }

    private func loadOrSeed() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            channels = try decoder.decode([Channel].self, from: data)
        } else {
            channels = ChannelStore.seed
            try save()
        }
    }

    // Curated 24/7 live news channels
    static let seed: [Channel] = [
        // Global News
        Channel(title: "Sky News", url: URL(string:"https://www.youtube.com/watch?v=9Auq9mYxFEE")!, group: "World"),
        Channel(title: "Al Jazeera English", url: URL(string:"https://www.youtube.com/watch?v=gCNeDWCI0vo")!, group: "World"),
        Channel(title: "BBC News", url: URL(string:"https://www.youtube.com/watch?v=pSa4yQr2fdQ")!, group: "World"),
        Channel(title: "DW News", url: URL(string:"https://www.youtube.com/watch?v=NiRIbKwAejk")!, group: "World"),
        Channel(title: "France 24 English", url: URL(string:"https://www.youtube.com/watch?v=l8PMl7tUDIE")!, group: "World"),
        
        // US News
        Channel(title: "NBC News NOW", url: URL(string:"https://www.youtube.com/watch?v=iEpJwprxDdk")!, group: "Finance"),
        Channel(title: "ABC News Live", url: URL(string:"https://www.youtube.com/watch?v=bNyUyrR0PHo")!, group: "Finance"),
        Channel(title: "CBS News 24/7", url: URL(string:"https://www.youtube.com/watch?v=f39oHo6vFLg")!, group: "Finance"),
        
        // Business News
        Channel(title: "Bloomberg Television", url: URL(string:"https://www.youtube.com/watch?v=dp8PhLsUcFE")!, group: "Finance"),
        Channel(title: "CNBC Television", url: URL(string:"https://www.youtube.com/watch?v=9NyxcX3rhQs")!, group: "Finance"),
        
        // Asian News
        Channel(title: "WION", url: URL(string:"https://www.youtube.com/watch?v=b6R9-7KZ8YM")!, group: "World"),
        Channel(title: "CNA", url: URL(string:"https://www.youtube.com/watch?v=XWq5kBlakcQ")!, group: "World"),
        
        // Tech & Innovation
        Channel(title: "Euronews", url: URL(string:"https://www.youtube.com/watch?v=pykpO5kQJ98")!, group: "Tech"),
    ]
}

