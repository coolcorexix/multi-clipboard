import Cocoa
import Foundation
import SwiftUI

public class ClipboardManager: ObservableObject {
    @Published public private(set) var recentItems: [ClipboardContent] = []
    
    public static let shared = ClipboardManager()
    private let storage: ClipboardStorage
    private let maxItems = 5000
    private let fileManager = FileManager.default
    private let dataDirectory: URL
    
    private init() {
        // Initialize storage
        storage = SQLiteClipboardStorage()
        
        // Setup data directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleId = Bundle.main.bundleIdentifier ?? "com.multiclipboard"
        dataDirectory = appSupport.appendingPathComponent(bundleId).appendingPathComponent("ClipboardData")
        
        // Create directory if needed
        try? fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        
        // Load initial items
        if storage.load() {
            updateRecentItems()
        }
    }
    
    private func updateRecentItems() {
        recentItems = storage.getAllItems()
    }
    
    public func addContent(_ value: String, type: ClipboardContentType, data: Data? = nil) {
        // Check for duplicates
        if let existingContent = storage.getItem(withId: value) {
            try? storage.deleteItem(withId: existingContent.id)
            try? storage.addItem(existingContent, withData: data)
            storage.save()
            updateRecentItems()
            return
        }
        
        var content = ClipboardContent(type: type, value: value)
        
        // Handle file data if provided
        if let data = data {
            let filename = "\(content.id).\(type == .image ? "png" : "dat")"
            let fileURL = dataDirectory.appendingPathComponent(filename)
            
            do {
                try data.write(to: fileURL)
                content.filePath = fileURL.path
                content.fileSize = Int64(data.count)
                print("Saved file data to: \(fileURL.path)")
            } catch {
                print("Failed to save file data: \(error)")
            }
        }
        
        // Add new content
        try? storage.addItem(content, withData: data)
        
        // Remove oldest if exceeding max
        if storage.getAllItems().count > maxItems {
            try? storage.deleteOldestItems(keepingOnly: maxItems)
        }
        
        // Save changes
        storage.save()
        
        // Update recent items
        updateRecentItems()
        
        // Post notification
        NotificationCenter.default.post(name: .clipboardContentDidChange, object: nil)
    }
    
    public var clipboardItems: [ClipboardContent] {
        return storage.getAllItems()
    }
    
    public func getRecentItems(limit: Int = 5) -> [ClipboardContent] {
        return Array(storage.getAllItems().prefix(limit))
    }
    
    private func handleDuplicateContent(_ content: String, type: ClipboardContentType) -> ClipboardContent? {
        return storage.getAllItems().first(where: { $0.value == content && $0.type == type })
    }
    
    public func getFileData(for content: ClipboardContent) -> Data? {
        guard let path = content.filePath else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }
    
    public func setAlias(_ alias: String?, forItemAt index: Int) {
        let items = storage.getAllItems()
        guard index < items.count else { return }
        var item = items[index]
        item.alias = alias
        try? storage.updateItem(item)
        updateRecentItems()
        NotificationCenter.default.post(name: .clipboardContentDidChange, object: nil)
    }
    
    private func deleteFileData(for content: ClipboardContent) {
        guard let path = content.filePath else { return }
        try? fileManager.removeItem(atPath: path)
    }
    
    func cleanup() {
        // Remove all stored files
        let existingFiles = (try? fileManager.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in existingFiles {
            try? fileManager.removeItem(at: file)
        }
        
        // Clear storage
        try? storage.deleteAllItems()
        storage.save()
        
        // Update recent items
        updateRecentItems()
    }
}

extension Notification.Name {
    static let clipboardContentDidChange = Notification.Name("com.multiclipboard.clipboardContentDidChange")
}

private extension Int {
    var toInt64: Int64 {
        Int64(self)
    }
} 