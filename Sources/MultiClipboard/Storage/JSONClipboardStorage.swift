import Foundation

public class JSONClipboardStorage: ClipboardStorage {
    private var clipboardHistory: [String: ClipboardContent] = [:]
    private let fileManager = FileManager.default
    
    private lazy var storageDirectory: URL? = {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let storageURL = appSupport.appendingPathComponent("MultiClipboard/Storage", isDirectory: true)
        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        return storageURL
    }()
    
    private var metadataURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport.appendingPathComponent("MultiClipboard/metadata.json")
    }
    
    public init() {
        try? initialize()
    }
    
    // MARK: - ClipboardStorage Protocol Implementation
    
    public func getAllItems() -> [ClipboardContent] {
        return Array(clipboardHistory.values).sorted { $0.createdAt > $1.createdAt }
    }
    
    public func addItem(_ content: ClipboardContent, withData data: Data?) throws {
        let id = content.id
        
        if let data = data {
            _ = try storeFileData(data, for: content)
        }
        print("Adding item with id: \(id)")
        clipboardHistory[id] = content
        print("Clipboard history: \(clipboardHistory)")
        try saveMetadata()
    }
    
    public func getItem(withId id: String) -> ClipboardContent? {
        return clipboardHistory[id]
    }
    
    public func updateItem(_ content: ClipboardContent) throws {
        let id = content.id
        
        clipboardHistory[id] = content
        try saveMetadata()
    }
    
    public func deleteItem(withId id: String) throws {
        if let content = clipboardHistory[id],
           let filePath = content.filePath,
           let storageDir = storageDirectory {
            let fileURL = storageDir.appendingPathComponent(filePath)
            try? fileManager.removeItem(at: fileURL)
        }
        
        clipboardHistory.removeValue(forKey: id)
        try saveMetadata()
    }
    
    public func getFileData(for content: ClipboardContent) -> Data? {
        guard let filePath = content.filePath,
              let storageDir = storageDirectory else {
            return nil
        }
        
        let fileURL = storageDir.appendingPathComponent(filePath)
        return try? Data(contentsOf: fileURL)
    }
    
    public func storeFileData(_ data: Data, for content: ClipboardContent) throws -> String? {
        let id = content.id
        guard let storageDir = storageDirectory else {
            return nil
        }
        
        let typeDir = storageDir.appendingPathComponent(content.type.rawValue, isDirectory: true)
        try fileManager.createDirectory(at: typeDir, withIntermediateDirectories: true)
        
        let filename = "\(id).\(content.type == .image ? "png" : "data")"
        let fileURL = typeDir.appendingPathComponent(filename)
        let relativePath = "\(content.type.rawValue)/\(filename)"
        
        try data.write(to: fileURL)
        return relativePath
    }
    
    public func deleteOldestItems(keepingOnly count: Int) throws {
        let sortedItems = clipboardHistory.sorted { $0.value.createdAt > $1.value.createdAt }
        
        for item in sortedItems[count...] {
            try deleteItem(withId: item.key)
        }
    }
    
    public func deleteAllItems() throws {
        if let storageDir = storageDirectory {
            try? fileManager.removeItem(at: storageDir)
        }
        
        clipboardHistory.removeAll()
        try saveMetadata()
    }
    
    public func cleanup() throws {
        // Optional: Implement cleanup of orphaned files
    }
    
    public func initialize() throws {
        try loadMetadata()
    }
    
    // MARK: - Private Methods
    
    private func saveMetadata() throws {
        guard let metadataURL = metadataURL else {
            throw StorageError.invalidStorageLocation
        }
        
        try fileManager.createDirectory(at: metadataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(clipboardHistory)
        try data.write(to: metadataURL)
    }
    
    private func loadMetadata() throws {
        guard let metadataURL = metadataURL else {
            throw StorageError.invalidStorageLocation
        }
        
        do {
            let data = try Data(contentsOf: metadataURL)
            let decoder = JSONDecoder()
            clipboardHistory = try decoder.decode([String: ClipboardContent].self, from: data)
        } catch {
            clipboardHistory = [:] // Start with empty history if loading fails
        }
    }
}

// MARK: - Error Types

public enum StorageError: Error {
    case invalidStorageLocation
    case invalidContent(String)
    case fileOperationFailed(String)
} 