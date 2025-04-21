import Foundation

public protocol ClipboardStorage {
    // Core operations
    func getAllItems() -> [ClipboardContent]
    func addItem(_ content: ClipboardContent, withData data: Data?) throws
    func getItem(withId id: String) -> ClipboardContent?
    func updateItem(_ content: ClipboardContent) throws
    func deleteItem(withId id: String) throws
    
    // File operations
    func getFileData(for content: ClipboardContent) -> Data?
    func storeFileData(_ data: Data, for content: ClipboardContent) throws -> String? // Returns file path if applicable
    
    // Batch operations
    func deleteOldestItems(keepingOnly count: Int) throws
    func deleteAllItems() throws
    
    // Maintenance
    func cleanup() throws
    func initialize() throws
} 