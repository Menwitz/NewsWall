import Foundation
import SwiftUI
import Combine

enum AppTheme: String, Codable, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case auto = "Auto"
}

final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()
    
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appTheme") }
    }
    
    @Published var accentColor: Color {
        didSet {
            if let data = try? JSONEncoder().encode(accentColor.toHex()) {
                UserDefaults.standard.set(data, forKey: "accentColor")
            }
        }
    }
    
    @Published var tileBorderStyle: TileBorderStyle {
        didSet { UserDefaults.standard.set(tileBorderStyle.rawValue, forKey: "tileBorderStyle") }
    }
    
    private init() {
        // Load theme
        if let themeRaw = UserDefaults.standard.string(forKey: "appTheme"),
           let savedTheme = AppTheme(rawValue: themeRaw) {
            self.theme = savedTheme
        } else {
            self.theme = .auto
        }
        
        // Load accent color
        if let data = UserDefaults.standard.data(forKey: "accentColor"),
           let hex = try? JSONDecoder().decode(String.self, from: data),
           let color = Color(hex: hex) {
            self.accentColor = color
        } else {
            self.accentColor = .blue
        }
        
        // Load border style
        if let styleRaw = UserDefaults.standard.string(forKey: "tileBorderStyle"),
           let savedStyle = TileBorderStyle(rawValue: styleRaw) {
            self.tileBorderStyle = savedStyle
        } else {
            self.tileBorderStyle = .minimal
        }
    }
    
    var effectiveColorScheme: ColorScheme? {
        switch theme {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil
        }
    }
}

enum TileBorderStyle: String, Codable, CaseIterable {
    case minimal = "Minimal"
    case bold = "Bold"
    case neon = "Neon"
}

// Helper extensions
extension Color {
    func toHex() -> String {
        guard let components = NSColor(self).cgColor.components else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
