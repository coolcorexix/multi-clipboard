import SQLite
import Foundation

class ClipboardTable {
    let table = Table("clipboard")
    let id = Expression<String>(value: "id")
    let type = Expression<String>(value: "type")
    let value = Expression<String>(value: "value")
    let createdAt = Expression<Double>(value: "createdAt")
    let alias = Expression<String?>(value: "alias")
    let fileSize = Expression<Int64?>(value: "fileSize")
    let filePath = Expression<String?>(value: "filePath")
    let mimeType = Expression<String?>(value: "mimeType")
    let destinationBundleId = Expression<String?>(value: "destinationBundleId") // Foreign key to DestinationTable.bundleId

    func createTable(in db: Connection) throws {
        try db.run(table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(type)
            t.column(value)
            t.column(createdAt)
            t.column(alias)
            t.column(fileSize)
            t.column(filePath)
            t.column(mimeType)
            t.column(destinationBundleId)
            // Foreign key constraint (SQLite.swift does not enforce, but you can document it)
            // .foreignKey(destinationBundleId, references: DestinationTable.table, DestinationTable.bundleId)
        })
    }
    // Add CRUD methods as needed
} 