import Foundation
import SQLite
// Table classes are in the same module and subfolder, so no explicit import is needed

public class SQLiteClipboardStorage: ClipboardStorage {
    private let db: Connection
    private let clipboardTable: ClipboardTable
    private let destinationTable: DestinationTable
    
    public var items: [ClipboardContent] = []
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let mainBundleId = Bundle.main.bundleIdentifier ?? "com.multiclipboard"
        let dbURL = appSupport.appendingPathComponent(mainBundleId).appendingPathComponent("clipboard.sqlite3")
        db = try! Connection(dbURL.path)

        // Initialize table modules
        clipboardTable = ClipboardTable()
        destinationTable = DestinationTable()
        // Create tables
        try! clipboardTable.createTable(in: db)
        try! destinationTable.createTable(in: db)
        _ = load()
    }
    
    public func load() -> Bool {
        do {
            items = try db.prepare(clipboardTable.table).map { row in
                ClipboardContent(
                    type: ClipboardContentType(rawValue: row[clipboardTable.type]) ?? .text,
                    value: row[clipboardTable.value],
                    alias: row[clipboardTable.alias],
                    fileSize: row[clipboardTable.fileSize],
                    filePath: row[clipboardTable.filePath],
                    mimeType: row[clipboardTable.mimeType]
                )
            }
            return true
        } catch {
            print("Failed to load clipboard history from SQLite: \(error)")
            items = []
            return false
        }
    }
    
    public func save() -> Bool {
        // No-op: each operation is persisted immediately
        return true
    }
    
    public func initialize() throws {
        // Already handled in init
    }
    
    public func getAllItems() -> [ClipboardContent] {
        return items
    }
    
    public func getItem(withId idValue: String) -> ClipboardContent? {
        return items.first { $0.id == idValue }
    }
    
    public func addItem(_ item: ClipboardContent, withData data: Data?) throws {
        try db.run(clipboardTable.table.insert(
            clipboardTable.id <- item.id,
            clipboardTable.type <- item.type.rawValue,
            clipboardTable.value <- item.value,
            clipboardTable.createdAt <- item.createdAt.timeIntervalSince1970,
            clipboardTable.alias <- item.alias,
            clipboardTable.fileSize <- item.fileSize,
            clipboardTable.filePath <- item.filePath,
            clipboardTable.mimeType <- item.mimeType
        ))
        _ = load()
    }
    
    public func updateItem(_ item: ClipboardContent) throws {
        let row = clipboardTable.table.filter(clipboardTable.id == item.id)
        try db.run(row.update(
            clipboardTable.type <- item.type.rawValue,
            clipboardTable.value <- item.value,
            clipboardTable.createdAt <- item.createdAt.timeIntervalSince1970,
            clipboardTable.alias <- item.alias,
            clipboardTable.fileSize <- item.fileSize,
            clipboardTable.filePath <- item.filePath,
            clipboardTable.mimeType <- item.mimeType
        ))
        _ = load()
    }
    
    public func deleteItem(withId idValue: String) throws {
        let row = clipboardTable.table.filter(clipboardTable.id == idValue)
        try db.run(row.delete())
        _ = load()
    }
    
    public func getFileData(for content: ClipboardContent) -> Data? {
        guard let path = content.filePath else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }
    
    public func storeFileData(_ data: Data, for content: ClipboardContent) throws -> String? {
        // Same as before: store in file system, return path
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleId = Bundle.main.bundleIdentifier ?? "com.multiclipboard"
        let dataDirectory = appSupport.appendingPathComponent(bundleId).appendingPathComponent("ClipboardData")
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let filename = "\(content.id).\(content.type == .image ? "png" : "dat")"
        let fileURL = dataDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL.path
    }
    
    public func cleanup() throws {
        try db.run(clipboardTable.table.delete())
        items.removeAll()
    }
    
    public func deleteOldestItems(keepingOnly count: Int) throws {
        let sorted = items.sorted { $0.createdAt > $1.createdAt }
        let toDelete = sorted.dropFirst(count)
        for item in toDelete {
            try deleteItem(withId: item.id)
        }
    }
    
    public func deleteAllItems() throws {
        try cleanup()
    }
} 