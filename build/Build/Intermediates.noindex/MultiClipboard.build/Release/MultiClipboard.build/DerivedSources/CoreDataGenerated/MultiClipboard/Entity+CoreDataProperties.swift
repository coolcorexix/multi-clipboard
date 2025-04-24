//
//  Entity+CoreDataProperties.swift
//  
//
//  Created by Huy Phát Phạm  on 24/4/25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Entity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Entity> {
        return NSFetchRequest<Entity>(entityName: "Entity")
    }

    @NSManaged public var alias: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var filePath: String?
    @NSManaged public var fileSize: Int64
    @NSManaged public var id: String?
    @NSManaged public var mimeType: String?
    @NSManaged public var type: String?
    @NSManaged public var value: String?

}

extension Entity : Identifiable {

}
