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
    
    static func createMainWindow() -> NSWindow {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        let contentView = ZStack {
            ContentView()
            SearchBarView(isVisible: .constant(true))  // Always visible
        }
        
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()
        panel.title = ""
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isFloatingPanel = true  // Makes it stay above other windows
        panel.level = .floating  // Makes it float above regular windows
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]  // Available in all spaces
        panel.delegate = windowDelegate
        
        // Hide the panel initially since we'll show it with the shortcut
        panel.orderOut(nil)
        
        return panel
    }
} 