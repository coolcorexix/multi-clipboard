import Cocoa
import Foundation

public class ClipboardManager {
    public static let shared = ClipboardManager()
    private let storage: ClipboardStorage
    private let maxHistoryItems = 50 // Limit the number of items we store
    
    public var clipboardItems: [ClipboardContent] {
        storage.getAllItems()
    }
    
    public init(storage: ClipboardStorage = CoreDataClipboardStorage()) {
        self.storage = storage
        try? storage.initialize()
    }
    
    public func addContent(_ content: String, type: ClipboardContentType) {
        addContent(content, type: type, data: nil)
    }
    
    public func addContent(_ content: String, type: ClipboardContentType, data: Data?) {
        print("\n=== Adding New Content ===")
        print("Type: \(type)")
        print("Content: \(content)")
        
        let clipboardContent = ClipboardContent(
            type: type,
            value: content,
            fileSize: data?.count.toInt64,
            mimeType: type == .image ? "image/png" : type == .video ? "video/mp4" : nil
        )
        
        do {
            try storage.addItem(clipboardContent, withData: data)
            // try storage.deleteOldestItems(keepingOnly: maxHistoryItems)
            
            // Notify observers that content changed
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .clipboardContentDidChange, object: nil)
            }
        } catch {
            print("Error adding content: \(error)")
        }
    }
    
    public func getFileData(for content: ClipboardContent) -> Data? {
        storage.getFileData(for: content)
    }
    
    public func setAlias(_ alias: String?, forItemAt index: Int) {
        let items = clipboardItems
        guard index < items.count else { return }
        
        var updatedItem = items[index]
        updatedItem.alias = alias
        
        do {
            try storage.updateItem(updatedItem)
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .clipboardContentDidChange, object: nil)
            }
        } catch {
            print("Error setting alias: \(error)")
        }
    }
}

private extension Int {
    var toInt64: Int64 {
        Int64(self)
    }
} 