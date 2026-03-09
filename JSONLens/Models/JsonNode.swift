import Foundation

enum JsonValue {
    case object([(String, JsonValue)])
    case array([JsonValue])
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null

    var type: JsonNodeType {
        switch self {
        case .object: return .object
        case .array: return .array
        case .string: return .string
        case .number: return .number
        case .boolean: return .boolean
        case .null: return .null
        }
    }

    var shortDisplay: String {
        switch self {
        case .object(let items):
            return "Object (\(items.count))"
        case .array(let items):
            return "Array (\(items.count))"
        case .string(let value):
            return value
        case .number(let value):
            let text = String(value)
            return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
        case .boolean(let value):
            return value ? "true" : "false"
        case .null:
            return "null"
        }
    }
}

enum JsonPathComponent: Hashable, Codable {
    case key(String)
    case index(Int)

    var stableKey: String {
        switch self {
        case .key(let key):
            let length = key.utf8.count
            return "k\(length)#\(key)"
        case .index(let index):
            return "i\(index)"
        }
    }

    var userPath: String {
        switch self {
        case .key(let key): return ".\(key)"
        case .index(let index): return "[\(index)]"
        }
    }
}

struct JsonNodeLocation: Hashable {
    var basePath: [JsonPathComponent]
    var embeddedPath: [JsonPathComponent]

    var id: String {
        "B:\(Self.serialize(basePath))|E:\(Self.serialize(embeddedPath))"
    }

    var displayPath: String {
        let base = Self.pathString(basePath)
        guard !embeddedPath.isEmpty else { return base }
        return "\(base) (embedded \(Self.pathString(embeddedPath)))"
    }

    static func pathString(_ path: [JsonPathComponent]) -> String {
        if path.isEmpty { return "$" }
        return "$" + path.map { $0.userPath }.joined()
    }

    static func serialize(_ path: [JsonPathComponent]) -> String {
        path.map { $0.stableKey }.joined(separator: "|")
    }
}

enum JsonNodeType: String, CaseIterable {
    case object
    case array
    case string
    case number
    case boolean
    case null
}

enum JsonNodeSource: String {
    case native
    case embedded
}

struct JsonNode: Identifiable {
    let location: JsonNodeLocation
    let key: String?
    let type: JsonNodeType
    let source: JsonNodeSource
    let displayValue: String
    let rawValue: JsonValue
    let childCount: Int
    let isExpandedByDefault: Bool
    let canExpandEmbedded: Bool
    var children: [JsonNode]

    var id: String { location.id }
    var isContainer: Bool { type == .object || type == .array }
    var childrenOrNil: [JsonNode]? { children.isEmpty ? nil : children }
}
