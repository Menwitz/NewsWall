import SwiftUI

struct KeywordAlertsView: View {
    @State private var keywords: [String] = TranscriptionEngine.shared.keywordAlerts
    @State private var newKeyword = ""
    @State private var showingAddSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyword Alerts")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Label("Add Keyword", systemImage: "plus")
                }
            }
            .padding()
            
            Divider()
            
            // Keywords list
            if keywords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No keyword alerts")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add keywords to get notified when they're mentioned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(keywords, id: \.self) { keyword in
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.accentColor)
                            Text(keyword)
                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            let keyword = keywords[index]
                            TranscriptionEngine.shared.removeKeyword(keyword)
                        }
                        keywords = TranscriptionEngine.shared.keywordAlerts
                    }
                }
            }
            
            Divider()
            
            // Info footer
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Keywords are case-insensitive")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 350, height: 400)
        .sheet(isPresented: $showingAddSheet) {
            AddKeywordSheet(
                isPresented: $showingAddSheet,
                keyword: $newKeyword,
                onAdd: {
                    if !newKeyword.isEmpty {
                        TranscriptionEngine.shared.addKeyword(newKeyword)
                        keywords = TranscriptionEngine.shared.keywordAlerts
                        newKeyword = ""
                    }
                }
            )
        }
    }
}

struct AddKeywordSheet: View {
    @Binding var isPresented: Bool
    @Binding var keyword: String
    var onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Keyword Alert")
                .font(.headline)
            
            TextField("Keyword or phrase", text: $keyword)
                .textFieldStyle(.roundedBorder)
            
            Text("You'll be notified when this keyword is mentioned on any channel")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                    keyword = ""
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Add") {
                    onAdd()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(keyword.isEmpty)
            }
        }
        .padding()
        .frame(width: 300, height: 180)
    }
}

struct TranscriptionFeedView: View {
    @State private var transcriptions: [(channelTitle: String, text: String, timestamp: Date)] = []
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Live Transcriptions")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    transcriptions.removeAll()
                }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(transcriptions.indices.reversed(), id: \.self) { index in
                        let item = transcriptions[index]
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.channelTitle)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(item.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(item.text)
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            setupTranscriptionListener()
        }
    }
    
    private func setupTranscriptionListener() {
        TranscriptionEngine.shared.onTranscription = { channelID, text in
            // For now, we'll just use the channel ID as title
            // In production, you'd look up the actual channel title
            transcriptions.append((
                channelTitle: "Channel \(channelID.uuidString.prefix(8))",
                text: text,
                timestamp: Date()
            ))
            
            // Keep only last 100 transcriptions
            if transcriptions.count > 100 {
                transcriptions.removeFirst()
            }
        }
    }
}
