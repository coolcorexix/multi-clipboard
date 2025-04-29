import Foundation

public protocol ClipboardStorage {
    var items: [ClipboardContent] { get set }
    func load() -> Bool
    func save() -> Bool
    func initialize() throws
    func addItem(_ item: ClipboardContent, withData data: Data?) throws
    func updateItem(_ item: ClipboardContent) throws
    func getAllItems() -> [ClipboardContent]
    func getFileData(for content: ClipboardContent) -> Data?
    
    // Core operations
    func getItem(withId id: String) -> ClipboardContent?
    func deleteItem(withId id: String) throws
    
    // File operations
    func storeFileData(_ data: Data, for content: ClipboardContent) throws -> String? // Returns file path if applicable
    
    // Batch operations
    func deleteOldestItems(keepingOnly count: Int) throws
    func deleteAllItems() throws
    
    // Maintenance
    func cleanup() throws
} 