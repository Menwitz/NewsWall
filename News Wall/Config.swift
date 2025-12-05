import Foundation


struct GridConfig {
    static var rows: Int {
        get { SettingsStore.shared.rows }
        set { SettingsStore.shared.rows = newValue }
    }
    static var cols: Int {
        get { SettingsStore.shared.cols }
        set { SettingsStore.shared.cols = newValue }
    }
    static var ytControls: Bool {
        get { SettingsStore.shared.ytControls }
        set { SettingsStore.shared.ytControls = newValue }
    }
    static var watchdogInterval: TimeInterval { SettingsStore.shared.watchdogInterval }
    static var watchdogStallTicks: Int { SettingsStore.shared.watchdogStallTicks }
}
