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

    // Initial favorites — adjust to taste
    static let seed: [Channel] = [
        Channel(title: "Feed 1", url: URL(string:"https://youtu.be/pSa4yQr2fdQ")!),
        Channel(title: "Feed 2", url: URL(string:"https://youtu.be/KQp-e_XQnDE")!),
        Channel(title: "Feed 3", url: URL(string:"https://youtu.be/NiRIbKwAejk")!),
        Channel(title: "Feed 4", url: URL(string:"https://youtu.be/l8PMl7tUDIE")!),
        Channel(title: "Feed 5", url: URL(string:"https://youtu.be/iEpJwprxDdk")!),
        Channel(title: "Feed 6", url: URL(string:"https://youtu.be/bNyUyrR0PHo")!),
        Channel(title: "Feed 7", url: URL(string:"https://youtu.be/f39oHo6vFLg")!),
        Channel(title: "Feed 8", url: URL(string:"https://youtu.be/gCNeDWCI0vo")!),
        Channel(title: "Feed 9", url: URL(string:"https://youtu.be/b6R9-7KZ8YM")!)
    ]
}

