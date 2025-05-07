import SwiftUI
import Cocoa
import Foundation

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
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @State private var notificationObserver: NSObjectProtocol?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
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
                
                // Set up notification observer for clipboard changes
                notificationObserver = NotificationCenter.default.addObserver(
                    forName: .clipboardContentDidChange,
                    object: nil,
                    queue: .main
                ) { _ in
                    Task {
                        await performSearch(query: searchText)
                    }
                }
            }
            .onDisappear {
                // Clean up notification observer
                if let observer = notificationObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        }
    }
    
    private func performSearch(query: String) async {
        let allItems = clipboardManager.clipboardItems
        
        // Helper function to deduplicate items
        func deduplicateItems(_ items: [ClipboardContent]) -> [ClipboardContent] {
            var uniqueItems: [String: ClipboardContent] = [:]
            
            items.forEach { content in
                let key: String
                if content.type == .image {
                    // For images, use the hash of the image data as the key
                    if let data = clipboardManager.getFileData(for: content) {
                        print("data: \(data.hashValue)")
                        key = String(data.hashValue)
                    } else {
                        key = content.value // Fallback to value if no data
                    }
                } else {
                    // For other types, use the value as before
                    key = content.value
                }
                
                // Keep the most recent version if duplicate
                if uniqueItems[key] == nil || 
                   (uniqueItems[key]?.createdAt ?? Date.distantPast) < content.createdAt {
                    uniqueItems[key] = content
                }
            }
            
            return Array(uniqueItems.values).sorted { $0.createdAt > $1.createdAt }
        }
        
        if query.isEmpty {
            await MainActor.run {
                print("\n=== Recent Items ===")
                // Deduplicate recent items
                searchState.searchResults = deduplicateItems(clipboardManager.recentItems)
            }
            return
        }
        
        // Filter items based on search query
        let filteredItems = allItems.filter { content in
            let searchableText = [
                content.value.lowercased(),
                content.alias?.lowercased() ?? "",
                content.type.rawValue.lowercased(),
                content.type == .image ? "image" : "",
                content.type == .video ? "video" : "",
                content.type == .file ? "file" : "",
                content.type == .text ? "text" : ""
            ].joined(separator: " ")
            
            return searchableText.contains(query.lowercased())
        }
        
        // Deduplicate filtered items
        let results = deduplicateItems(filteredItems)
        
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
        // Activate last active app before sending Cmd+V
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let lastApp = appDelegate.lastActiveApp {
            let appWithTabBundleIds = ["com.google.Chrome", "com.apple.Safari"]
            print("lastApp: \(lastApp.localizedName)")
            print("lastApp: \(lastApp.bundleIdentifier)")
            if appWithTabBundleIds.contains(lastApp.bundleIdentifier ?? "") {
                let activeTab = AppWithTabHelper.getActiveTab(bundleName: lastApp.localizedName ?? "")
                print("activeTab: \(activeTab)")
            }
            
            lastApp.activate(options: [NSApplication.ActivationOptions.activateIgnoringOtherApps, NSApplication.ActivationOptions.activateAllWindows])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                PasteSimulator.sendPasteCommand()
            }
        } else {
            PasteSimulator.sendPasteCommand()
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
                    ScrollViewReader { proxy in
                        VStack(spacing: 8) {
                            ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, content in
                                SearchResultRow(
                                    content: content,
                                    isSelected: index == selectedIndex,
                                    onSelect: { onSelect(content) }
                                )
                                .id(index) // Add id for scrolling
                            }
                        }
                        .padding(.horizontal)
                        .onChange(of: selectedIndex) { newIndex in
                            if let index = newIndex {
                                withAnimation {
                                    proxy.scrollTo(index, anchor: .center)
                                }
                            }
                        }
                    }
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
    @State private var previewImage: NSImage? = nil
    private let clipboardManager = ClipboardManager.shared
    
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
                if content.type == .image {
                    Group {
                        if let image = previewImage {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: icon)
                                .foregroundColor(isSelected || isHovered ? .white : .gray)
                                .frame(width: 40, height: 40)
                        }
                    }
                } else {
                    Image(systemName: icon)
                        .foregroundColor(isSelected || isHovered ? .white : .gray)
                        .frame(width: 24)
                }
                
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
        .onAppear {
            if content.type == .image {
                loadImagePreview()
            }
        }
    }
    
    private func loadImagePreview() {
        if let data = clipboardManager.getFileData(for: content),
           let image = NSImage(data: data) {
            previewImage = image
        }
    }
}

// Preview provider for SwiftUI canvas
struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        SearchBarView()
    }
}



