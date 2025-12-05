import Foundation
import SwiftUI
import Combine

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    @Published var rows: Int {
        didSet { UserDefaults.standard.set(rows, forKey: "gridRows") }
    }
    @Published var cols: Int {
        didSet { UserDefaults.standard.set(cols, forKey: "gridCols") }
    }
    @Published var ytControls: Bool {
        didSet { UserDefaults.standard.set(ytControls, forKey: "ytControls") }
    }
    @Published var watchdogInterval: Double {
        didSet { UserDefaults.standard.set(watchdogInterval, forKey: "watchdogInterval") }
    }
    @Published var watchdogStallTicks: Int {
        didSet { UserDefaults.standard.set(watchdogStallTicks, forKey: "watchdogStallTicks") }
    }
    
    private init() {
        UserDefaults.standard.register(defaults: [
            "gridRows": 4,
            "gridCols": 4,
            "ytControls": false,
            "watchdogInterval": 6.0,
            "watchdogStallTicks": 4
        ])
        
        self.rows = UserDefaults.standard.integer(forKey: "gridRows")
        self.cols = UserDefaults.standard.integer(forKey: "gridCols")
        self.ytControls = UserDefaults.standard.bool(forKey: "ytControls")
        self.watchdogInterval = UserDefaults.standard.double(forKey: "watchdogInterval")
        self.watchdogStallTicks = UserDefaults.standard.integer(forKey: "watchdogStallTicks")
    }
}
