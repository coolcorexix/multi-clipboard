import Cocoa
import HotKey

// Enum to represent different types of clipboard content
enum ClipboardContentType {
    case text
    case image
}

// Structure to store clipboard content with metadata
struct ClipboardContent: Codable {
    let type: ClipboardContentType
    let value: String // For text, this is the text itself. For images, this is the image name
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case type, value, createdAt
    }
    
    // Custom encoding for ClipboardContentType
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(type == .text ? "text" : "image", forKey: .type)
    }
    
    // Custom decoding for ClipboardContentType
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(String.self, forKey: .value)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        let typeString = try container.decode(String.self, forKey: .type)
        type = typeString == "text" ? .text : .image
    }
    
    init(type: ClipboardContentType, value: String, createdAt: Date = Date()) {
        self.type = type
        self.value = value
        self.createdAt = createdAt
    }
}

// Add this after ClipboardContent definition
extension Notification.Name {
    static let clipboardContentDidChange = Notification.Name("clipboardContentDidChange")
}

class ClipboardManager {
    static let shared = ClipboardManager()
    private var clipboardHistory: [String: ClipboardContent] = [:]
    private let maxHistoryItems = 50 // Limit the number of items we store
    
    private init() {
        loadHistory()
    }
    
    func addContent(_ content: String, type: ClipboardContentType) {
        print("\n=== Adding New Content ===")
        print("Type: \(type)")
        print("Content: \(content)")
        
        let key: String
        let value: String
        
        switch type {
        case .text:
            key = content
            value = content
        case .image:
            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            key = "image_\(dateStr)"
            value = key
        }
        
        let clipboardContent = ClipboardContent(type: type, value: value)
        clipboardHistory[key] = clipboardContent
        
        print("\n=== Current Clipboard History ===")
        for (key, content) in clipboardHistory {
            print("Key: \(key)")
            print("Value: \(content.value)")
            print("Type: \(content.type)")
            print("Created: \(content.createdAt)")
            print("---")
        }
        
        // Remove oldest items if we exceed the limit
        if clipboardHistory.count > maxHistoryItems {
            let sortedItems = clipboardHistory.sorted { $0.value.createdAt > $1.value.createdAt }
            let newHistory = sortedItems.prefix(maxHistoryItems)
            clipboardHistory = Dictionary(uniqueKeysWithValues: newHistory.map { ($0.key, $0.value) })
        }
        
        saveHistory()
        
        // Notify observers that content changed
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clipboardContentDidChange, object: nil)
        }
    }
    
    func getContent(for key: String) -> ClipboardContent? {
        return clipboardHistory[key]
    }
    
    func getAllContent() -> [ClipboardContent] {
        print("\n=== Getting All Content ===")
        let items = Array(clipboardHistory.values).sorted { $0.createdAt > $1.createdAt }
        print("Number of items: \(items.count)")
        for item in items {
            print("Value: \(item.value)")
            print("Type: \(item.type)")
            print("Created: \(item.createdAt)")
            print("---")
        }
        return items
    }
    
    private func saveHistory() {
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentDirectory.appendingPathComponent("clipboard_history.json")
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(clipboardHistory)
                try data.write(to: fileURL)
            } catch {
                print("Error saving clipboard history: \(error)")
            }
        }
    }
    
    private func loadHistory() {
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentDirectory.appendingPathComponent("clipboard_history.json")
            
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                clipboardHistory = try decoder.decode([String: ClipboardContent].self, from: data)
            } catch {
                print("Error loading clipboard history: \(error)")
                clipboardHistory = [:] // Start with empty history if loading fails
            }
        }
    }
}

class HistoryWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var clipboardItems: [ClipboardContent] = []
    
    convenience init() {
        print("Creating history window")
        // Create a window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clipboard History"
        window.center()
        window.minSize = NSSize(width: 400, height: 300)
        
        // Important: Set window to be visible when created
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
    }
    
    override init(window: NSWindow?) {
        super.init(window: window)
        print("Window controller initialized")
        setupUI()
        reloadData()
        
        // Register for clipboard content changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipboardContentDidChange),
            name: .clipboardContentDidChange,
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        print("Window did load")
    }
    
    private func setupUI() {
        guard let window = self.window,
              let contentView = window.contentView else { return }
        
        // Create scroll view
        scrollView = NSScrollView(frame: contentView.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        

        // Create table view
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.style = .fullWidth
        tableView.usesAlternatingRowBackgroundColors = true
        
        // Add columns
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = "Date"
        dateColumn.width = 150
        dateColumn.minWidth = 100
        tableView.addTableColumn(dateColumn)
        
        let contentColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
        contentColumn.title = "Content"
        contentColumn.width = 300
        contentColumn.minWidth = 200
        tableView.addTableColumn(contentColumn)
        
        // Setup scroll view
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        // Add a search field
        let searchField = NSSearchField(frame: NSRect(x: 10, y: contentView.bounds.height - 30, width: 200, height: 24))
        searchField.placeholderString = "Search"
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(searchField)
        
        // Adjust scroll view frame to accommodate search field
        scrollView.frame = NSRect(
            x: 0,
            y: 0,
            width: contentView.bounds.width,
            height: contentView.bounds.height - 40
        )
    }
    
    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        reloadData(searchText: sender.stringValue)
    }
    
    @objc private func clipboardContentDidChange() {
        reloadData()
    }
    
    func reloadData(searchText: String = "") {
        print("Reloading data")
        clipboardItems = ClipboardManager.shared.getAllContent()
        print("Found \(clipboardItems.count) items")
        
        if !searchText.isEmpty {
            clipboardItems = clipboardItems.filter { item in
                item.value.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Ensure table view updates happen on main thread
        if Thread.isMainThread {
            tableView.reloadData()
        } else {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return clipboardItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView = NSTableCellView()
        cellView.frame = NSRect(x: 0, y: 0, width: tableColumn?.width ?? 100, height: 50)
        
        let textField = NSTextField(frame: NSRect(x: 5, y: 0, width: (tableColumn?.width ?? 100) - 10, height: 50))
        textField.isEditable = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.maximumNumberOfLines = 1
        textField.cell?.truncatesLastVisibleLine = true
        textField.lineBreakMode = .byTruncatingTail
        textField.autoresizingMask = [.width, .height]
        textField.alignment = .left
        textField.font = NSFont.systemFont(ofSize: 13)
        
        // Configure cell for vertical alignment
        if let cell = textField.cell as? NSTextFieldCell {
            cell.isScrollable = true
            cell.wraps = false
            cell.usesSingleLineMode = true
        }
        
        let item = clipboardItems[row]
        
        if tableColumn?.identifier.rawValue == "date" {
            textField.stringValue = item.createdAt.description
        } else if tableColumn?.identifier.rawValue == "content" {
            textField.stringValue = item.type == .text ? item.value : "[Image] " + item.value
            
            // Add a copy button
            let buttonWidth: CGFloat = 65
            let buttonHeight: CGFloat = 24
            let buttonX = cellView.frame.width - buttonWidth - 10
            let buttonY = (cellView.frame.height - buttonHeight) / 2
            
            let copyButton = NSButton(frame: NSRect(x: buttonX, y: buttonY, width: buttonWidth, height: buttonHeight))
            copyButton.title = "Copy"
            copyButton.bezelStyle = NSButton.BezelStyle.rounded
            copyButton.target = self
            copyButton.action = #selector(copyContent(_:))
            copyButton.tag = row
            cellView.addSubview(copyButton)
            
            // Adjust text field width to accommodate button
            textField.frame.size.width = buttonX - 10
        }
        
        cellView.addSubview(textField)
        cellView.textField = textField
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 50 // Increased from 30 to 50
    }
    
    @objc private func copyContent(_ sender: NSButton) {
        let row = sender.tag
        let item = clipboardItems[row]
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            pasteboard.setString(item.value, forType: .string)
        case .image:
            if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let imageURL = documentDirectory.appendingPathComponent("\(item.value).png")
                if let imageData = try? Data(contentsOf: imageURL) {
                    pasteboard.setData(imageData, forType: .png)
                }
            }
        }
    }
    
    @objc func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        reloadData()  // Refresh data when window is shown
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var hotKey: HotKey?
    private var lastChangeCount: Int = 0
    private var clipboardTimer: Timer?
    private var historyWindowController: HistoryWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "MultiClipboard")
        }
        
        setupMenu()
        setupHotKey()
        setupServices()
        setupClipboardMonitoring()
        
        // Check accessibility permissions
        checkAccessibilityPermissions()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "MultiClipboard", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show History", action: #selector(showHistory), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Check Permissions", action: #selector(checkAccessibilityPermissions), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    func setupHotKey() {
        // Setup Cmd + Y hotkey
        hotKey = HotKey(key: .y, modifiers: [.command])
        
        hotKey?.keyDownHandler = { [weak self] in
            self?.handleHotKeyPress()
        }
    }
    
    func setupServices() {
        // Register for Services menu
        NSApp.servicesProvider = self
        
        // Register the service
        NSApplication.shared.registerServicesMenuSendTypes([.string], returnTypes: [])
    }
    
    func setupClipboardMonitoring() {
        // Store initial change count
        lastChangeCount = NSPasteboard.general.changeCount
        
        // Invalidate existing timer if any
        clipboardTimer?.invalidate()
        
        // Create a timer and retain it strongly
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboardChanges()
        }
        
        // Make the timer more tolerant of timing delays
        timer.tolerance = 0.1
        
        // Add the timer to the main run loop with multiple modes to ensure it keeps running
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
        RunLoop.main.add(timer, forMode: .modalPanel)
        
        // Store the timer strongly
        clipboardTimer = timer
        
        print("Clipboard monitoring started")
    }
    
    func checkClipboardChanges() {
        let currentCount = NSPasteboard.general.changeCount
        if currentCount != lastChangeCount {
            lastChangeCount = currentCount
            print("Clipboard change detected: Count changed from \(lastChangeCount) to \(currentCount)")
            
            // Check for text content
            if let copiedString = NSPasteboard.general.string(forType: .string) {
                print("New clipboard content detected: \(copiedString)")
                // Add to clipboard history
                ClipboardManager.shared.addContent(copiedString, type: .text)
                // No need to show prompt anymore since we have the history window
            }
            // Check for image content
            else if let copiedImage = NSPasteboard.general.data(forType: .tiff) ?? NSPasteboard.general.data(forType: .png) {
                let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
                let imageName = "image_\(dateStr)"
                print("New image content detected: \(imageName)")
                // Add to clipboard history
                ClipboardManager.shared.addContent(imageName, type: .image)
                
                // Save the image data
                if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let imageURL = documentDirectory.appendingPathComponent("\(imageName).png")
                    try? copiedImage.write(to: imageURL)
                }
            }
        }
    }
    
    @objc func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessibilityEnabled {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "MultiClipboard needs accessibility permissions to read selected text. Please:\n\n1. Open System Settings\n2. Go to Privacy & Security > Accessibility\n3. Click the + button\n4. Navigate to the MultiClipboard app and add it\n5. Enable the toggle for MultiClipboard"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")
            
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }
    
    func handleHotKeyPress() {
        print("Hot key pressed")
        print(AXIsProcessTrusted())
        if !AXIsProcessTrusted() {
            checkAccessibilityPermissions()
            return
        }
        
        if let selectedText = getSelectedText() {
            print("Selected text: \(selectedText)")
            showPrompt(with: selectedText)
        }
    }
    
    func getSelectedText() -> String? {
        // Check accessibility permissions first
        if !AXIsProcessTrusted() {
            checkAccessibilityPermissions()
            return nil
        }

        // Get the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let frontmostPID = frontmostApp.processIdentifier as? pid_t else {
            return nil
        }
        
        print("Attempting to get text from app: \(frontmostApp.localizedName ?? "Unknown")")
        
        // Get the AXUIElement for the application
        let appRef = AXUIElementCreateApplication(frontmostPID)
        
        // Get the focused element
        var focusedElement: AnyObject?
        let focusedResult = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        print("Focused result for \(frontmostApp.localizedName ?? "Unknown"): \(focusedResult)")
        
        if focusedResult == .success {
            // Try to get selected text
            var selectedText: AnyObject?
            let selectedResult = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)
            print("Selected text result for \(frontmostApp.localizedName ?? "Unknown"): \(selectedResult)")
            
            if selectedResult == .success, let text = selectedText as? String {
                print("Successfully got text via accessibility API")
                return text
            }
        }
        
        print("Falling back to clipboard method for \(frontmostApp.localizedName ?? "Unknown")")
        
        // Fallback to pasteboard method if accessibility method fails
        let pasteboard: NSPasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems
        let fallbackText = #selector(NSText.copy(_:));
        print("Fallback text: \(fallbackText)")
        // Save current selection to pasteboard
        NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
        
        // Small delay to ensure pasteboard is updated
        Thread.sleep(forTimeInterval: 0.1)
        
        let text = pasteboard.string(forType: .string)
        
        // Restore previous pasteboard content
        pasteboard.clearContents()
        if let items = savedItems {
            for item in items {
                pasteboard.writeObjects([item])
            }
        }
        
        return text
    }
    
    func showPrompt(with text: String) {
        let alert = NSAlert()
        alert.messageText = "Add to MultiClipboard"
        alert.informativeText = "Selected text:\n\(text)"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        // Run the alert as a sheet if we have a window, otherwise run it modally
        if let window = NSApp.windows.first(where: { $0.isVisible }) {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    // Handle adding to clipboard history here
                    print("Added to clipboard: \(text)")
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Handle adding to clipboard history here
                print("Added to clipboard: \(text)")
            }
        }
    }
    
    // Service menu handler
    @objc func handleService(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        if let text = pboard.string(forType: .string) {
            showPrompt(with: text)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up timer when app terminates
        clipboardTimer?.invalidate()
    }
    
    @objc func showHistory() {
        print("Show history called")
        if historyWindowController == nil {
            print("Creating new history window controller")
            historyWindowController = HistoryWindowController()
        }
        
        print("Showing window")
        historyWindowController?.showWindow(self)
        
        // Make sure app is active
        NSApp.activate(ignoringOtherApps: true)
        
        // Force window to front
        if let window = historyWindowController?.window {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            print("Window frame: \(window.frame)")
        } else {
            print("Window is nil!")
        }
    }
}

// Create and start the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run() 