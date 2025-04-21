import Foundation
import CoreData

public class CoreDataClipboardStorage: ClipboardStorage {
    private let container: NSPersistentContainer
    private let fileManager = FileManager.default
    
    private lazy var storageDirectory: URL? = {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let storageURL = appSupport.appendingPathComponent("MultiClipboard/Storage", isDirectory: true)
        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        return storageURL
    }()
    
    public init() {
        // Create the managed object model programmatically
        let model = NSManagedObjectModel()
        
        // Create the ClipboardItem entity
        let clipboardItemEntity = NSEntityDescription()
        clipboardItemEntity.name = "ClipboardItem"
        clipboardItemEntity.managedObjectClassName = "ClipboardItem"
        
        // Create attributes
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .stringAttributeType
        idAttribute.isOptional = false
        
        let typeAttribute = NSAttributeDescription()
        typeAttribute.name = "type"
        typeAttribute.attributeType = .stringAttributeType
        typeAttribute.isOptional = false
        
        let valueAttribute = NSAttributeDescription()
        valueAttribute.name = "value"
        valueAttribute.attributeType = .stringAttributeType
        valueAttribute.isOptional = false
        
        let createdAtAttribute = NSAttributeDescription()
        createdAtAttribute.name = "createdAt"
        createdAtAttribute.attributeType = .dateAttributeType
        createdAtAttribute.isOptional = false
        
        let aliasAttribute = NSAttributeDescription()
        aliasAttribute.name = "alias"
        aliasAttribute.attributeType = .stringAttributeType
        aliasAttribute.isOptional = true
        
        let fileSizeAttribute = NSAttributeDescription()
        fileSizeAttribute.name = "fileSize"
        fileSizeAttribute.attributeType = .integer64AttributeType
        fileSizeAttribute.isOptional = false
        fileSizeAttribute.defaultValue = 0
        
        let filePathAttribute = NSAttributeDescription()
        filePathAttribute.name = "filePath"
        filePathAttribute.attributeType = .stringAttributeType
        filePathAttribute.isOptional = true
        
        let mimeTypeAttribute = NSAttributeDescription()
        mimeTypeAttribute.name = "mimeType"
        mimeTypeAttribute.attributeType = .stringAttributeType
        mimeTypeAttribute.isOptional = true
        
        // Add attributes to entity
        clipboardItemEntity.properties = [
            idAttribute,
            typeAttribute,
            valueAttribute,
            createdAtAttribute,
            aliasAttribute,
            fileSizeAttribute,
            filePathAttribute,
            mimeTypeAttribute
        ]
        
        // Add entity to model
        model.entities = [clipboardItemEntity]
        
        // Create container with our model
        container = NSPersistentContainer(name: "MultiClipboard", managedObjectModel: model)
        
        // Set up the persistent store (database) location
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let databaseDirectoryURL = appSupportURL.appendingPathComponent("MultiClipboard", isDirectory: true)
        let databaseURL = databaseDirectoryURL.appendingPathComponent("clipboard.db")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: databaseDirectoryURL, withIntermediateDirectories: true)
        
        // Configure the persistent store
        let storeDescription = NSPersistentStoreDescription(url: databaseURL)
        storeDescription.type = NSSQLiteStoreType  // Explicitly specify we're using SQLite
        container.persistentStoreDescriptions = [storeDescription]
        
        // Load the persistent store synchronously
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
    }
    
    // MARK: - ClipboardStorage Protocol Implementation
    
    public func getAllItems() -> [ClipboardContent] {
        let context = container.viewContext
        let fetchRequest = ClipboardItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let items = try context.fetch(fetchRequest)
            return items.map { $0.toContent() }
        } catch {
            print("Error fetching items: \(error)")
            return []
        }
    }
    
    public func addItem(_ content: ClipboardContent, withData data: Data?) throws {
        let context = container.viewContext
        
        if let data = data {
            let filePath = try storeFileData(data, for: content)
            var updatedContent = content
            updatedContent.filePath = filePath
            _ = ClipboardItem.create(in: context, from: updatedContent)
        } else {
            _ = ClipboardItem.create(in: context, from: content)
        }
        
        try context.save()
    }
    
    public func getItem(withId id: String) -> ClipboardContent? {
        let context = container.viewContext
        let fetchRequest = ClipboardItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let items = try context.fetch(fetchRequest)
            return items.first?.toContent()
        } catch {
            print("Error fetching item: \(error)")
            return nil
        }
    }
    
    public func updateItem(_ content: ClipboardContent) throws {
        let context = container.viewContext
        let fetchRequest = ClipboardItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", content.id)
        
        do {
            let items = try context.fetch(fetchRequest)
            if let item = items.first {
                item.update(from: content)
                try context.save()
            }
        } catch {
            throw StorageError.invalidContent("Failed to update item: \(error)")
        }
    }
    
    public func deleteItem(withId id: String) throws {
        let context = container.viewContext
        let fetchRequest = ClipboardItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let items = try context.fetch(fetchRequest)
            if let item = items.first {
                if let filePath = item.filePath,
                   let storageDir = storageDirectory {
                    let fileURL = storageDir.appendingPathComponent(filePath)
                    try? fileManager.removeItem(at: fileURL)
                }
                context.delete(item)
                try context.save()
            }
        } catch {
            throw StorageError.invalidContent("Failed to delete item: \(error)")
        }
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
        guard let storageDir = storageDirectory else {
            return nil
        }
        
        let typeDir = storageDir.appendingPathComponent(content.type.rawValue, isDirectory: true)
        try fileManager.createDirectory(at: typeDir, withIntermediateDirectories: true)
        
        let filename = "\(content.id).\(content.type == .image ? "png" : "data")"
        let fileURL = typeDir.appendingPathComponent(filename)
        let relativePath = "\(content.type.rawValue)/\(filename)"
        
        try data.write(to: fileURL)
        return relativePath
    }
    
    public func deleteOldestItems(keepingOnly count: Int) throws {
        let context = container.viewContext
        let fetchRequest = ClipboardItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let items = try context.fetch(fetchRequest)
            for item in items.dropFirst(count) {
                if let filePath = item.filePath,
                   let storageDir = storageDirectory {
                    let fileURL = storageDir.appendingPathComponent(filePath)
                    try? fileManager.removeItem(at: fileURL)
                }
                context.delete(item)
            }
            try context.save()
        } catch {
            throw StorageError.invalidContent("Failed to delete oldest items: \(error)")
        }
    }
    
    public func deleteAllItems() throws {
        let context = container.viewContext
        let fetchRequest = ClipboardItem.fetchRequest()
        
        do {
            let items = try context.fetch(fetchRequest)
            for item in items {
                if let filePath = item.filePath,
                   let storageDir = storageDirectory {
                    let fileURL = storageDir.appendingPathComponent(filePath)
                    try? fileManager.removeItem(at: fileURL)
                }
                context.delete(item)
            }
            try context.save()
            
            // Clean up storage directory
            if let storageDir = storageDirectory {
                try? fileManager.removeItem(at: storageDir)
            }
        } catch {
            throw StorageError.invalidContent("Failed to delete all items: \(error)")
        }
    }
    
    public func cleanup() throws {
        // Optional: Implement cleanup of orphaned files
    }
    
    public func initialize() throws {
        // Load persistent stores
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Error loading persistent stores: \(error)")
            }
        }
    }
} 