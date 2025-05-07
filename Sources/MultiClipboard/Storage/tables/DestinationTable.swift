import SQLite
import Foundation

class DestinationTable {
    let table = Table("destination")
    let id = Expression<String>(value: "id") // New primary key
    let bundleId = Expression<String>(value: "bundleId")
    let localizedName = Expression<String>(value: "localizedName")
    let clipboardId = Expression<String?>(value: "clipboardId") // Foreign key to ClipboardTable.id

    func createTable(in db: Connection) throws {
        try db.run(table.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(bundleId)
            t.column(localizedName)
            t.column(clipboardId)
            // Foreign key constraint (SQLite.swift does not enforce, but you can document it)
            // .foreignKey(clipboardId, references: ClipboardTable.table, ClipboardTable.id)
        })
    }
    // Add CRUD methods as needed
}