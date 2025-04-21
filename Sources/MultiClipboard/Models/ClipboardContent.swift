import Foundation

public enum ClipboardContentType: String, Codable {
    case text
    case image
    case video
    case file
}

public struct ClipboardContent: Codable {
    public let id: String
    public let type: ClipboardContentType
    public let value: String // For text, this is the text itself. For media/files, this is the file reference
    public let createdAt: Date
    public var alias: String?
    public var fileSize: Int64?  // Size in bytes
    public var filePath: String? // Path relative to storage directory
    public var mimeType: String? // MIME type for files
    
    enum CodingKeys: String, CodingKey {
        case id, type, value, createdAt, alias, fileSize, filePath, mimeType
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(value, forKey: .value)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(alias, forKey: .alias)
        try container.encodeIfPresent(fileSize, forKey: .fileSize)
        try container.encodeIfPresent(filePath, forKey: .filePath)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try ClipboardContentType(rawValue: container.decode(String.self, forKey: .type)) ?? .text
        value = try container.decode(String.self, forKey: .value)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        alias = try container.decodeIfPresent(String.self, forKey: .alias)
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
    }
    
    public init(type: ClipboardContentType, value: String, alias: String? = nil, fileSize: Int64? = nil, filePath: String? = nil, mimeType: String? = nil) {
        self.id = UUID().uuidString
        self.type = type
        self.value = value
        self.createdAt = Date()
        self.alias = alias
        self.fileSize = fileSize
        self.filePath = filePath
        self.mimeType = mimeType
    }
} 