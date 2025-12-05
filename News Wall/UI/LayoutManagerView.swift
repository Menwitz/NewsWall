import SwiftUI

struct LayoutManagerView: View {
    @ObservedObject var layoutStore = LayoutStore.shared
    @State private var showingNewLayout = false
    @State private var newLayoutName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Layout Profiles")
                    .font(.headline)
                Spacer()
                Button(action: { showingNewLayout = true }) {
                    Label("New", systemImage: "plus")
                }
            }
            .padding()
            
            Divider()
            
            // Layout List
            List {
                ForEach(layoutStore.layouts) { layout in
                    LayoutRow(layout: layout, isActive: layoutStore.activeLayoutID == layout.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            layoutStore.activateLayout(layout)
                        }
                }
                .onDelete { indexSet in
                    indexSet.forEach { layoutStore.deleteLayout(layoutStore.layouts[$0]) }
                }
            }
        }
        .frame(width: 350, height: 400)
        .sheet(isPresented: $showingNewLayout) {
            NewLayoutSheet(isPresented: $showingNewLayout, layoutName: $newLayoutName)
        }
    }
}

struct LayoutRow: View {
    let layout: Layout
    let isActive: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(layout.name)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                Text("\(layout.rows)×\(layout.cols) • \(layout.channelIDs.count) channels")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}

struct NewLayoutSheet: View {
    @Binding var isPresented: Bool
    @Binding var layoutName: String
    @ObservedObject var settingsStore = SettingsStore.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Layout")
                .font(.headline)
            
            TextField("Layout Name", text: $layoutName)
                .textFieldStyle(.roundedBorder)
            
            Text("Current grid size: \(settingsStore.rows)×\(settingsStore.cols)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                    layoutName = ""
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Create") {
                    let layout = Layout(
                        name: layoutName.isEmpty ? "Untitled" : layoutName,
                        rows: settingsStore.rows,
                        cols: settingsStore.cols
                    )
                    LayoutStore.shared.addLayout(layout)
                    LayoutStore.shared.activateLayout(layout)
                    isPresented = false
                    layoutName = ""
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300, height: 180)
    }
}
