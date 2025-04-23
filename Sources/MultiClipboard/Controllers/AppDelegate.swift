import Cocoa
import HotKey
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    var statusItem: NSStatusItem?
    private var clipboardHotKey: HotKey?
    private var searchHotKey: HotKey?
    private var lastChangeCount: Int = 0
    private var clipboardTimer: Timer?
    private var historyWindowController: HistoryWindowController?
    var searchPanel: NSWindow?
    private var lastActiveWindow: NSWindow?
    private var lastActiveApp: NSRunningApplication?
    @Published var isSearchBarVisible = false {
        didSet {
            if isSearchBarVisible {
                searchPanel?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                searchPanel?.orderOut(nil)
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Application did finish launching")
        // Create and store the search panel
        searchPanel = MultiClipboardApp.createMainWindow()
        
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "MultiClipboard")
        }
        
        setupMenu()
        setupKeyboardShortcuts()
        setupServices()
        setupClipboardMonitoring()
        
        // Check accessibility permissions
        checkAccessibilityPermissions()
    }
    
    func setupMenu() {
        // 1. Setup Main Menu (for keyboard shortcuts)
        let mainMenu = NSMenu()
        
        // Edit Menu (put this first for better shortcut handling)
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = NSMenu(title: "Edit")
        let editMenu = editMenuItem.submenu!
        
        // Add a hidden menu item to ensure Edit menu exists
        editMenu.addItem(withTitle: "Edit", action: nil, keyEquivalent: "")
        
        // Add standard edit menu items
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        mainMenu.addItem(editMenuItem)
        
        // Application Menu
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = NSMenu()
        let appMenu = appMenuItem.submenu!
        appMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        mainMenu.addItem(appMenuItem)
        
        // Set the application's main menu
        NSApp.mainMenu = mainMenu
        
        // 2. Setup Status Item Menu (existing menu)
        let statusMenu = NSMenu()
        statusMenu.addItem(NSMenuItem(title: "MultiClipboard", action: nil, keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Show History", action: #selector(showHistory), keyEquivalent: "h"))
        statusMenu.addItem(NSMenuItem(title: "Check Permissions", action: #selector(checkAccessibilityPermissions), keyEquivalent: "p"))
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = statusMenu
    }
    
    func setupKeyboardShortcuts() {
        // Setup Cmd + Y hotkey for clipboard operations
        clipboardHotKey = HotKey(key: .y, modifiers: [.command])
        clipboardHotKey?.keyDownHandler = { [weak self] in
            self?.handleClipboardHotKeyPress()
        }
        
        // Setup Cmd + Shift + F hotkey for search
        searchHotKey = HotKey(key: .w, modifiers: [.command, .shift])
        searchHotKey?.keyDownHandler = { [weak self] in
            self?.toggleSearchPanel()
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
    
    func handleClipboardHotKeyPress() {
        print("Clipboard hot key pressed")
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
            historyWindowController = HistoryWindowController(clipboardManager: ClipboardManager.shared)
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
    
    @objc func showSearchPanel() {
        // Store the current active application before showing our panel
        lastActiveApp = NSWorkspace.shared.frontmostApplication
        print("Last active app: \(String(describing: lastActiveApp?.localizedName))")
        
        searchPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func hideSearchPanel() {
        searchPanel?.orderOut(nil)
        
        // Restore focus to the last active application
        if let lastApp = lastActiveApp {
            lastApp.activate(options: .activateIgnoringOtherApps)
        }
        lastActiveApp = nil
    }
    
    @objc private func toggleSearchPanel() {
        if searchPanel?.isVisible == true {
            hideSearchPanel()
        } else {
            showSearchPanel()
        }
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Always enable Edit menu items when there's a text field active
        if menuItem.action == #selector(NSText.cut(_:)) ||
           menuItem.action == #selector(NSText.copy(_:)) ||
           menuItem.action == #selector(NSText.paste(_:)) ||
           menuItem.action == #selector(NSText.selectAll(_:)) {
            // Return true to enable the menu item and its keyboard shortcut
            return true
        }
        return true
    }
} 