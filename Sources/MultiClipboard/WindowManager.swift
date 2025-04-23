import Foundation
import AppKit

class WindowManager {
    private weak var window: NSWindow?
    private weak var owner: AnyObject?
    private let name: String
    
    init(window: NSWindow, owner: AnyObject, name: String) {
        self.window = window
        self.owner = owner
        self.name = name
        
        setupWindowBehavior()
    }
    
    private func setupWindowBehavior() {
        guard let window = window else { return }
        
        // Set window to appear in all spaces and handle full screen
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Observe space changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSpaceChange),
            name: NSWindow.didChangeScreenNotification,
            object: window
        )
        
        // Observe window movement
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowMove),
            name: NSWindow.didMoveNotification,
            object: window
        )
        
        print("Debug: \(name) frame = \(window.frame)")
        print("Debug: \(name) level = \(window.level.rawValue)")
        print("Debug: \(name) collection behavior = \(window.collectionBehavior.rawValue)")
    }
    
    @objc private func handleSpaceChange() {
        print("\(name): Space change detected")
        ensureWindowVisibility()
    }
    
    @objc private func handleWindowMove() {
        print("\(name): Window moved")
        ensureWindowVisibility()
    }
    
    private func ensureWindowVisibility() {
        guard let window = window else { return }
        print("\(name): Ensuring window visibility...")
        window.orderFront(nil)
        window.level = .statusBar
        
        // Make sure window is visible in the current space
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.orderFront(nil)
            window.level = .statusBar
        }
    }
    
    deinit {
        // Remove observers when the manager is deallocated
        if let window = window {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeScreenNotification, object: window)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: window)
        }
    }
} 