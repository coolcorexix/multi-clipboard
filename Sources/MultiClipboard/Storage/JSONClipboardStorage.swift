import Foundation

public class JSONClipboardStorage: ClipboardStorage {
    private let fileManager = FileManager.default
    private let storageURL: URL
    private let dataDirectory: URL
    
    public var items: [ClipboardContent] = []
    
    public init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleId = Bundle.main.bundleIdentifier ?? "com.multiclipboard"
        let appDirectory = appSupport.appendingPathComponent(bundleId)
        
        storageURL = appDirectory.appendingPathComponent("clipboard_history.json")
        dataDirectory = appDirectory.appendingPathComponent("ClipboardData")
        
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        
        _ = load()
    }
    
    public func load() -> Bool {
        if !fileManager.fileExists(atPath: storageURL.path) {
            items = []
            return save()
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            items = try JSONDecoder().decode([ClipboardContent].self, from: data)
            return true
        } catch {
            print("Failed to load clipboard history: \(error)")
            return false
        }
    }
    
    public func save() -> Bool {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL)
            return true
        } catch {
            print("Failed to save clipboard history: \(error)")
            return false
        }
    }
    
    public func initialize() throws {
        if !fileManager.fileExists(atPath: storageURL.path) {
            items = []
            try? save()
        }
    }
    
    public func getAllItems() -> [ClipboardContent] {
        return items
    }
    
    public func getItem(withId id: String) -> ClipboardContent? {
        return items.first { $0.id == id }
    }
    
    public func addItem(_ item: ClipboardContent, withData data: Data?) throws {
        if let data = data {
            let filename = "\(item.id).\(item.type == .image ? "png" : "dat")"
            let fileURL = dataDirectory.appendingPathComponent(filename)
            try data.write(to: fileURL)
            
            var updatedItem = item
            updatedItem.filePath = fileURL.path
            updatedItem.fileSize = Int64(data.count)
            items.insert(updatedItem, at: 0)
        } else {
            items.insert(item, at: 0)
        }
        
        try? save()
    }
    
    public func updateItem(_ item: ClipboardContent) throws {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            try? save()
        }
    }
    
    public func deleteItem(withId id: String) throws {
        if let index = items.firstIndex(where: { $0.id == id }) {
            let item = items[index]
            if let filePath = item.filePath {
                try? fileManager.removeItem(atPath: filePath)
            }
            items.remove(at: index)
            try? save()
        }
    }
    
    public func getFileData(for content: ClipboardContent) -> Data? {
        guard let path = content.filePath else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }
    
    public func storeFileData(_ data: Data, for content: ClipboardContent) throws -> String? {
        let filename = "\(content.id).\(content.type == .image ? "png" : "dat")"
        let fileURL = dataDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL.path
    }
    
    public func cleanup() throws {
        // Remove all files in the data directory
        let files = try? fileManager.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: nil)
        try files?.forEach { try fileManager.removeItem(at: $0) }
        
        // Clear items array
        items.removeAll()
        try? save()
    }
    
    public func deleteOldestItems(keepingOnly count: Int) throws {
        // Sort items by creation date, newest first
        let sortedItems = items.sorted { $0.createdAt > $1.createdAt }
        
        // Keep only the specified number of newest items
        items = Array(sortedItems.prefix(count))
        
        // Delete file data for removed items
        let removedItems = sortedItems.dropFirst(count)
        for item in removedItems {
            if let filePath = item.filePath {
                try? fileManager.removeItem(atPath: filePath)
            }
        }
        
        try? save()
    }
    
    public func deleteAllItems() throws {
        try cleanup()
    }
}

// MARK: - Error Types

public enum StorageError: Error {
    case invalidStorageLocation
    case invalidContent(String)
    case fileOperationFailed(String)
} 