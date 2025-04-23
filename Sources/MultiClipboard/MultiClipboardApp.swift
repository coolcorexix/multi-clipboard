import SwiftUI

class SearchPanelDelegate: NSObject, NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.hideSearchPanel()
        }
    }
}

struct MultiClipboardApp {
    static let windowDelegate = SearchPanelDelegate()
    static var windowManager: WindowManager?
    
    static func createMainWindow() -> NSWindow {
        // Create the content view
        let contentView = SearchBarView()
            .background(Color.clear)
        
        // Create a hosting view with a size that accommodates the search bar
        let hostingView = NSHostingView(rootView: contentView)
        
        // Set initial size to accommodate the search bar and potential results
        // Width: minimum 600 for the search bar plus padding
        // Height: search bar height (60) + padding
        let initialSize = NSSize(width: 640, height: 400) // 600 + 40 for padding
        
        // Create the panel with the initial size
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.contentView = hostingView
        panel.center()
        panel.title = ""
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isFloatingPanel = true
        panel.level = .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.delegate = windowDelegate
        
        // Set minimum window size to ensure search bar is never too small
        panel.minSize = NSSize(width: 640, height: 400)
        
        // Hide the panel initially since we'll show it with the shortcut
        panel.orderOut(nil)
        
        // Create window manager with NSObject as owner since we don't need strong reference
        windowManager = WindowManager(window: panel, owner: NSObject(), name: "SearchPanel")
        
        return panel
    }
} 