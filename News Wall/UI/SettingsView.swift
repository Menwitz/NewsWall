import SwiftUI

struct SettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @ObservedObject var themeStore = ThemeStore.shared
    
    var body: some View {
        Form {
            Section(header: Text("Grid Layout")) {
                Stepper("Rows: \(store.rows)", value: $store.rows, in: 1...5)
                Stepper("Columns: \(store.cols)", value: $store.cols, in: 1...5)
            }
            
            Section(header: Text("Playback")) {
                Toggle("Show YouTube Controls", isOn: $store.ytControls)
                
                HStack {
                    Text("Watchdog Interval")
                    Slider(value: $store.watchdogInterval, in: 1...30, step: 1)
                    Text("\(Int(store.watchdogInterval))s")
                }
            }
            
            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $themeStore.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                
                ColorPicker("Accent Color", selection: $themeStore.accentColor)
                
                Picker("Tile Border Style", selection: $themeStore.tileBorderStyle) {
                    ForEach(TileBorderStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
            }
        }
        .padding()
        .frame(width: 350, height: 250)
    }
}
