import Foundation
import Combine

final class LayoutStore: ObservableObject {
    static let shared = LayoutStore()
    
    @Published var layouts: [Layout] = []
    @Published var activeLayoutID: UUID?
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileURL: URL
    
    var activeLayout: Layout? {
        guard let id = activeLayoutID else { return nil }
        return layouts.first { $0.id == id }
    }
    
    private init() {
        let appSupport = try! FileManager.default.url(for: .applicationSupportDirectory,
                                                       in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = appSupport.appendingPathComponent("NewsWall", isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("layouts.json")
        
        load()
    }
    
    func load() {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let data = try? Data(contentsOf: fileURL),
               let decoded = try? decoder.decode([Layout].self, from: data) {
                layouts = decoded
            }
        }
        
        // Create default layout if none exist
        if layouts.isEmpty {
            let defaultLayout = Layout(name: "Default", rows: 3, cols: 3)
            layouts.append(defaultLayout)
            activeLayoutID = defaultLayout.id
            save()
        }
    }
    
    func save() {
        if let data = try? encoder.encode(layouts) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }
    
    func addLayout(_ layout: Layout) {
        layouts.append(layout)
        save()
    }
    
    func updateLayout(_ layout: Layout) {
        if let index = layouts.firstIndex(where: { $0.id == layout.id }) {
            layouts[index] = layout
            save()
        }
    }
    
    func deleteLayout(_ layout: Layout) {
        layouts.removeAll { $0.id == layout.id }
        if activeLayoutID == layout.id {
            activeLayoutID = layouts.first?.id
        }
        save()
    }
    
    func activateLayout(_ layout: Layout) {
        var updated = layout
        updated.lastUsed = Date()
        updateLayout(updated)
        activeLayoutID = layout.id
    }
}
