import Foundation

enum ChannelGroup: String, Codable, CaseIterable {
    case all = "All"
    case finance = "Finance"
    case world = "World"
    case tech = "Tech"
    case arabic = "Arabic"
    case custom = "Custom"
}

struct GridConfig {
    static var rows: Int = 3     // change at runtime via hotkeys
    static var cols: Int = 3
    static var ytControls: Bool = false // set true to show minimal controls
    static let watchdogInterval: TimeInterval = 6.0  // seconds
    static let watchdogStallTicks: Int = 4           // N intervals without progress => reload
}
