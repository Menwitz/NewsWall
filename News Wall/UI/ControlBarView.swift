import SwiftUI

struct ControlBarView: View {
    @ObservedObject var store = SettingsStore.shared
    var onMuteAll: () -> Void
    var onReloadAll: () -> Void
    var onSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: onMuteAll) {
                Label("Mute All", systemImage: "speaker.slash")
            }
            
            Button(action: onReloadAll) {
                Label("Reload All", systemImage: "arrow.clockwise")
            }
            
            Divider().frame(height: 20)
            
            HStack(spacing: 4) {
                Text("Rows:")
                Picker("", selection: $store.rows) {
                    ForEach(1...5, id: \.self) { Text("\($0)") }
                }
                .frame(width: 50)
            }
            
            HStack(spacing: 4) {
                Text("Cols:")
                Picker("", selection: $store.cols) {
                    ForEach(1...5, id: \.self) { Text("\($0)") }
                }
                .frame(width: 50)
            }
            
            Spacer()
            
            Button(action: onSettings) {
                Label("Settings", systemImage: "gear")
            }
        }
        .padding(10)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(12)
        .padding()
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
