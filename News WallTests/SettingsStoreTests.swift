import XCTest
@testable import News_Wall

final class SettingsStoreTests: XCTestCase {

    func testDefaults() {
        let store = SettingsStore.shared
        // Reset to defaults for testing (optional, but good practice if tests run in random order)
        // Since it's a singleton using standard UserDefaults, we might be reading previous state.
        // For a robust test, we should inject a UserDefaults instance, but for now let's check basic types.
        
        XCTAssertGreaterThan(store.rows, 0)
        XCTAssertGreaterThan(store.cols, 0)
        XCTAssertGreaterThan(store.watchdogInterval, 0)
    }

    func testUpdate() {
        let store = SettingsStore.shared
        let oldRows = store.rows
        
        store.rows = 5
        XCTAssertEqual(store.rows, 5)
        XCTAssertEqual(GridConfig.rows, 5, "GridConfig should reflect SettingsStore")
        
        // Restore
        store.rows = oldRows
    }
}
