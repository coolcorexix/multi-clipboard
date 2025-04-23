import SwiftUI

class SearchState: ObservableObject {
    @Published var searchResults: [ClipboardContent] = [] {
        didSet {
            // Update dependent properties
            self.hasResults = !searchResults.isEmpty
            self.resultsCount = searchResults.count
        }
    }
    
    @Published var selectedIndex: Int? = nil
    @Published private(set) var hasResults: Bool = false
    @Published private(set) var resultsCount: Int = 0
}

struct SearchBarView: View {
    @State private var searchText: String = ""
    @FocusState private var isFocused: Bool
    @StateObject private var searchState = SearchState()
    private let clipboardManager = ClipboardManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // Search bar container
                VStack(spacing: 0) {
                    SearchTextField(
                        searchText: $searchText,
                        searchState: searchState,
                        onSubmit: {
                            if let selectedIndex = searchState.selectedIndex,
                               selectedIndex < searchState.searchResults.count {
                                let selectedContent = searchState.searchResults[selectedIndex]
                                copyToClipboard(content: selectedContent)
                                if let appDelegate = NSApp.delegate as? AppDelegate {
                                    appDelegate.hideSearchPanel()
                                }
                            } else if let firstResult = searchState.searchResults.first {
                                // Fallback to first result if nothing is selected
                                copyToClipboard(content: firstResult)
                                if let appDelegate = NSApp.delegate as? AppDelegate {
                                    appDelegate.hideSearchPanel()
                                }
                            }
                        },
                        onClear: {
                            searchText = ""
                            searchState.searchResults = []
                            searchState.selectedIndex = nil
                        },
                        onExit: {
                            if let appDelegate = NSApp.delegate as? AppDelegate {
                                appDelegate.hideSearchPanel()
                            }
                        }
                    )
                    .onChange(of: searchText) { newValue in
                        Task { @MainActor in
                            await performSearch(query: newValue)
                            searchState.selectedIndex = nil
                        }
                    }
                }
                .frame(width: min(600, geometry.size.width * 0.8))
                .padding(.horizontal)
                
                // Results view
                SearchResultsView(
                    searchResults: searchState.searchResults,
                    selectedIndex: $searchState.selectedIndex,
                    geometry: geometry,
                    onSelect: { content in
                        copyToClipboard(content: content)
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.hideSearchPanel()
                        }
                    }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.windowBackgroundColor))
                    .shadow(radius: 10)
            )
            .onAppear {
                isFocused = true
                // Call performSearch with empty query to show recent items
                Task {
                    await performSearch(query: "")
                }
            }
        }
    }
    
    private func performSearch(query: String) async {
        let allItems = clipboardManager.clipboardItems
        
        if query.isEmpty {
            await MainActor.run {
                print("\n=== Recent Items ===")
                // Items are already sorted by createdAt in storage layer
                let recentItems = allItems.prefix(5)
                recentItems.forEach { content in
                    print("\(content.createdAt): \(content.value)")
                }
                searchState.searchResults = Array(recentItems)
            }
            return
        }
        
        var uniqueItems: [String: ClipboardContent] = [:]
        
        allItems.filter { content in
            let searchableText = [
                content.value.lowercased(),
                content.alias?.lowercased() ?? ""
            ].joined(separator: " ")
            
            return searchableText.contains(query.lowercased())
        }.forEach { content in
            if uniqueItems[content.value] == nil || 
               (uniqueItems[content.value]?.createdAt ?? Date.distantPast) < content.createdAt {
                uniqueItems[content.value] = content
            }
        }
        
        let results = Array(uniqueItems.values).sorted { $0.createdAt > $1.createdAt }
        
        await MainActor.run {
            searchState.searchResults = results
        }
    }
    
    private func copyToClipboard(content: ClipboardContent) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch content.type {
        case .text:
            pasteboard.setString(content.value, forType: .string)
        case .image:
            if let data = clipboardManager.getFileData(for: content),
               let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        case .video, .file:
            if let data = clipboardManager.getFileData(for: content) {
                let type = content.type == .video ? NSPasteboard.PasteboardType("public.movie") : NSPasteboard.PasteboardType("public.data")
                pasteboard.setData(data, forType: type)
            }
        }
    }
}

// MARK: - Search Results View
struct SearchResultsView: View {
    let searchResults: [ClipboardContent]
    @Binding var selectedIndex: Int?
    let geometry: GeometryProxy
    let onSelect: (ClipboardContent) -> Void
    
    var body: some View {
        if !searchResults.isEmpty {
            VStack {
                Divider()
                    .background(Color.gray.opacity(0.2))
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, content in
                            SearchResultRow(
                                content: content,
                                isSelected: index == selectedIndex,
                                onSelect: { onSelect(content) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: min(400, geometry.size.height * 0.6))
            }
        }
    }
}

// MARK: - Search Text Field
struct SearchTextField: View {
    @Binding var searchText: String
    @ObservedObject var searchState: SearchState
    @FocusState private var innerFocused: Bool
    let onSubmit: () -> Void
    let onClear: () -> Void
    let onExit: () -> Void
    @State private var eventMonitor: Any?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 20))
            
            TextField("Search", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit(onSubmit)
                .focused($innerFocused)
            
            if !searchText.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // ESC key code
                    onExit()
                    return nil
                }
                
                if searchState.resultsCount > 0 {
                    if event.keyCode == 125 { // Down arrow key code
                        if searchState.selectedIndex == nil {
                            searchState.selectedIndex = 0
                        } else if let current = searchState.selectedIndex {
                            searchState.selectedIndex = min(current + 1, searchState.resultsCount - 1)
                        }
                        return nil
                    }
                    
                    if event.keyCode == 126 { // Up arrow key code
                        if let current = searchState.selectedIndex {
                            searchState.selectedIndex = max(current - 1, 0)
                        }
                        return nil
                    }
                }
                
                if event.keyCode == 36 && searchState.selectedIndex != nil { // Return key code
                    onSubmit()
                    return nil
                }
                
                return event
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let content: ClipboardContent
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    
    private var icon: String {
        switch content.type {
        case .text: return "doc.text"
        case .image: return "photo"
        case .video: return "video"
        case .file: return "doc"
        }
    }
    
    private var displayText: String {
        if let alias = content.alias {
            return alias
        }
        switch content.type {
        case .text: return content.value
        case .image: return "[Image]"
        case .video: return "[Video]"
        case .file: return "[File]"
        }
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: content.createdAt, relativeTo: Date())
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isSelected || isHovered ? .white : .gray)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayText)
                        .lineLimit(2)
                        .foregroundColor(isSelected || isHovered ? .white : .primary)
                    
                    if content.alias != nil && content.type == .text {
                        Text(content.value)
                            .font(.caption)
                            .foregroundColor(isSelected || isHovered ? .white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                    }
                    
                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundColor(isSelected || isHovered ? .white.opacity(0.7) : .secondary)
                }
                
                Spacer()
            }
            .padding(12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected ? Color.accentColor :
                            isHovered ? Color.accentColor.opacity(0.8) :
                            Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Preview provider for SwiftUI canvas
struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        SearchBarView()
    }
}
