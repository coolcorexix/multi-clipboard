import Cocoa

final class HistoryWindowController: NSWindowController {
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private let clipboardManager: ClipboardManager
    private let byteCountFormatter = ByteCountFormatter()
    
    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
        
        let contentRect = NSRect(x: 0, y: 0, width: 600, height: 600)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        window.title = "MultiClipboard History"
        window.center()
        
        super.init(window: window)
        window.delegate = self
        
        setupTableView()
        
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
    
    private func setupTableView() {
        guard let window = self.window else { return }
        
        // Create scroll view
        scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        
        // Create table view
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.style = .plain
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        
        // Add column for type
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Type"
        typeColumn.width = 60
        typeColumn.minWidth = 60
        tableView.addTableColumn(typeColumn)
        
        // Add column for alias
        let aliasColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("alias"))
        aliasColumn.title = "Alias"
        aliasColumn.width = 100
        aliasColumn.minWidth = 50
        tableView.addTableColumn(aliasColumn)
        
        // Add column for content
        let contentColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
        contentColumn.title = "Content"
        contentColumn.width = scrollView.bounds.width - 280 // Account for other columns and scrollbar
        contentColumn.minWidth = 100
        tableView.addTableColumn(contentColumn)
        
        // Add column for size
        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeColumn.title = "Size"
        sizeColumn.width = 80
        sizeColumn.minWidth = 60
        tableView.addTableColumn(sizeColumn)
        
        // Set delegates
        tableView.delegate = self
        tableView.dataSource = self
        
        // Configure scroll view
        scrollView.documentView = tableView
        window.contentView?.addSubview(scrollView)
        
        // Initial data load
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc func copyContent(_ sender: NSButton) {
        let row = sender.tag
        let content = clipboardManager.clipboardItems[row]
        
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
    
    @objc func clipboardContentDidChange(_ notification: Notification) {
        tableView.reloadData()
    }
    
    @objc func aliasDidChange(_ sender: NSTextField) {
        let row = sender.tag
        let newAlias = sender.stringValue.isEmpty ? nil : sender.stringValue
        clipboardManager.setAlias(newAlias, forItemAt: row)
    }
    
    private func getContentDescription(for content: ClipboardContent) -> String {
        switch content.type {
        case .text:
            return content.value
        case .image:
            return "[Image] \(content.value)"
        case .video:
            return "[Video] \(content.value)"
        case .file:
            return "[File] \(content.value)"
        }
    }
    
    private func getTypeIcon(for type: ClipboardContentType) -> String {
        switch type {
        case .text:
            return "📝"
        case .image:
            return "🖼"
        case .video:
            return "🎥"
        case .file:
            return "📄"
        }
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate
extension HistoryWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return clipboardManager.clipboardItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnIdentifier = tableColumn?.identifier else { return nil }
        
        let clipboardContent = clipboardManager.clipboardItems[row]
        let cellView = NSTableCellView()
        
        switch columnIdentifier.rawValue {
        case "type":
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 60, height: 50))
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            textField.alignment = .center
            textField.stringValue = getTypeIcon(for: clipboardContent.type)
            cellView.addSubview(textField)
            cellView.textField = textField
            
        case "alias":
            let aliasField = NSTextField(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 100, height: 50))
            aliasField.isEditable = true
            aliasField.isBordered = false
            aliasField.drawsBackground = false
            aliasField.lineBreakMode = .byTruncatingTail
            aliasField.cell?.truncatesLastVisibleLine = true
            aliasField.cell?.wraps = false
            aliasField.autoresizingMask = [.width]
            aliasField.placeholderString = "Enter alias..."
            aliasField.stringValue = clipboardContent.alias ?? ""
            aliasField.target = self
            aliasField.action = #selector(aliasDidChange(_:))
            aliasField.tag = row
            cellView.addSubview(aliasField)
            cellView.textField = aliasField
            
        case "content":
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: (tableColumn?.width ?? tableView.bounds.width) - 60, height: 50))
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            textField.lineBreakMode = .byTruncatingTail
            textField.cell?.truncatesLastVisibleLine = true
            textField.cell?.wraps = true
            textField.autoresizingMask = [.width]
            textField.stringValue = getContentDescription(for: clipboardContent)
            
            let copyButton = NSButton(frame: NSRect(x: (tableColumn?.width ?? tableView.bounds.width) - 55, y: 10, width: 45, height: 30))
            copyButton.title = "Copy"
            copyButton.bezelStyle = .rounded
            copyButton.target = self
            copyButton.action = #selector(copyContent(_:))
            copyButton.tag = row
            copyButton.autoresizingMask = [.minXMargin]
            
            cellView.addSubview(textField)
            cellView.addSubview(copyButton)
            cellView.textField = textField
            
        case "size":
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 80, height: 50))
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            textField.alignment = .right
            
            if let fileSize = clipboardContent.fileSize {
                textField.stringValue = byteCountFormatter.string(fromByteCount: fileSize)
            } else {
                textField.stringValue = clipboardContent.type == .text ? 
                    byteCountFormatter.string(fromByteCount: Int64(clipboardContent.value.utf8.count)) : 
                    "-"
            }
            
            cellView.addSubview(textField)
            cellView.textField = textField
        default:
            return nil
        }
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 50
    }
}

// MARK: - NSWindowDelegate
extension HistoryWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Optional: Handle window closing if needed
    }
} 