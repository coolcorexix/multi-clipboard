import Foundation
import CoreData

@objc(ClipboardItem)
public class ClipboardItem: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClipboardItem> {
        return NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
    }
    
    @NSManaged public var id: String
    @NSManaged public var type: String
    @NSManaged public var value: String
    @NSManaged public var createdAt: Date
    @NSManaged public var alias: String?
    @NSManaged public var fileSize: Int64
    @NSManaged public var filePath: String?
    @NSManaged public var mimeType: String?
    
    public var contentType: ClipboardContentType {
        get {
            ClipboardContentType(rawValue: type) ?? .text
        }
        set {
            type = newValue.rawValue
        }
    }
}

// MARK: - Convenience Methods
extension ClipboardItem {
    static func create(in context: NSManagedObjectContext, from content: ClipboardContent) -> ClipboardItem {
        let item = ClipboardItem(context: context)
        item.update(from: content)
        return item
    }
    
    func toContent() -> ClipboardContent {
        ClipboardContent(
            type: contentType,
            value: value,
            alias: alias,
            fileSize: fileSize,
            filePath: filePath,
            mimeType: mimeType
        )
    }
    
    func update(from content: ClipboardContent) {
        id = content.id
        type = content.type.rawValue
        value = content.value
        createdAt = content.createdAt
        alias = content.alias
        fileSize = content.fileSize ?? 0
        filePath = content.filePath
        mimeType = content.mimeType
    }
} 