import Cocoa
import HotKey

// Create and configure the application
let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // This makes it a UI-less app that can show windows when needed

let delegate = AppDelegate()
app.delegate = delegate
app.run() 