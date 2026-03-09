import Foundation

enum JsonEditError: LocalizedError {
    case pathNotFound
    case invalidOperation(String)
    case embeddedParseFailed

    var errorDescription: String? {
        switch self {
        case .pathNotFound:
            return "Node path not found"
        case .invalidOperation(let message):
            return message
        case .embeddedParseFailed:
            return "Failed to parse embedded JSON string"
        }
    }
}

final class JsonEditService {
    private let parser: JsonParseService

    init(parser: JsonParseService) {
        self.parser = parser
    }

    func renameKey(root: JsonValue, location: JsonNodeLocation, newKey: String) throws -> JsonValue {
        let targetKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetKey.isEmpty else {
            throw JsonEditError.invalidOperation("Key cannot be empty")
        }

        return try mutate(root: root, location: location) { mutableRoot, path in
            guard let last = path.last else {
                throw JsonEditError.invalidOperation("Root key cannot be renamed")
            }
            guard case .key(let oldKey) = last else {
                throw JsonEditError.invalidOperation("Only object entries can be renamed")
            }
            let parentPath = Array(path.dropLast())
            try self.renameObjectKey(in: &mutableRoot, parentPath: parentPath, oldKey: oldKey, newKey: targetKey)
        }
    }

    func updateValue(root: JsonValue, location: JsonNodeLocation, newValue: JsonValue) throws -> JsonValue {
        return try mutate(root: root, location: location) { mutableRoot, path in
            mutableRoot = try self.replacingValue(in: mutableRoot, at: path, with: newValue)
        }
    }

    func addSibling(root: JsonValue, location: JsonNodeLocation) throws -> JsonValue {
        return try mutate(root: root, location: location) { mutableRoot, path in
            guard let last = path.last else {
                throw JsonEditError.invalidOperation("Root node has no sibling")
            }
            let parentPath = Array(path.dropLast())
            switch last {
            case .key:
                try self.insertObjectEntry(in: &mutableRoot, at: parentPath)
            case .index(let index):
                try self.insertArrayValue(in: &mutableRoot, at: parentPath, after: index)
            }
        }
    }

    func addChild(root: JsonValue, location: JsonNodeLocation) throws -> JsonValue {
        return try mutate(root: root, location: location) { mutableRoot, path in
            var target = try self.value(in: mutableRoot, at: path)
            switch target {
            case .object(var items):
                let key = self.uniqueKey(in: items.map { $0.0 }, preferred: "newKey")
                items.append((key, .null))
                target = .object(items)
            case .array(var items):
                items.append(.null)
                target = .array(items)
            default:
                throw JsonEditError.invalidOperation("Only object/array supports child insertion")
            }
            mutableRoot = try self.replacingValue(in: mutableRoot, at: path, with: target)
        }
    }

    func deleteNode(root: JsonValue, location: JsonNodeLocation) throws -> JsonValue {
        return try mutate(root: root, location: location) { mutableRoot, path in
            guard let last = path.last else {
                throw JsonEditError.invalidOperation("Root node cannot be deleted")
            }
            let parentPath = Array(path.dropLast())
            var parent = try self.value(in: mutableRoot, at: parentPath)

            switch (parent, last) {
            case (.object(var items), .key(let key)):
                items.removeAll(where: { $0.0 == key })
                parent = .object(items)
            case (.array(var items), .index(let index)):
                guard items.indices.contains(index) else { throw JsonEditError.pathNotFound }
                items.remove(at: index)
                parent = .array(items)
            default:
                throw JsonEditError.invalidOperation("Delete operation is not valid for this node")
            }
            mutableRoot = try self.replacingValue(in: mutableRoot, at: parentPath, with: parent)
        }
    }

    func coerceValue(from text: String, to targetType: JsonNodeType) throws -> JsonValue {
        switch targetType {
        case .string:
            return .string(text)
        case .number:
            guard let number = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw JsonEditError.invalidOperation("Invalid number")
            }
            return .number(number)
        case .boolean:
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "true" { return .boolean(true) }
            if normalized == "false" { return .boolean(false) }
            throw JsonEditError.invalidOperation("Boolean must be true or false")
        case .null:
            return .null
        case .object, .array:
            switch parser.parse(text: text) {
            case .success(let value):
                switch (targetType, value) {
                case (.object, .object), (.array, .array):
                    return value
                default:
                    throw JsonEditError.invalidOperation("Value type does not match selected container type")
                }
            case .failure(let error):
                throw JsonEditError.invalidOperation(error.message)
            }
        }
    }

    private func mutate(
        root: JsonValue,
        location: JsonNodeLocation,
        body: (inout JsonValue, [JsonPathComponent]) throws -> Void
    ) throws -> JsonValue {
        if location.embeddedPath.isEmpty {
            var mutableRoot = root
            try body(&mutableRoot, location.basePath)
            return mutableRoot
        }

        let baseValue = try value(in: root, at: location.basePath)
        guard case .string(let embeddedText) = baseValue else {
            throw JsonEditError.embeddedParseFailed
        }

        let embeddedRoot: JsonValue
        switch parser.parse(text: embeddedText) {
        case .success(let value):
            embeddedRoot = value
        case .failure:
            throw JsonEditError.embeddedParseFailed
        }

        var mutableEmbedded = embeddedRoot
        try body(&mutableEmbedded, location.embeddedPath)
        let rewritten = try parser.stringify(value: mutableEmbedded, pretty: false)
        return try replacingValue(in: root, at: location.basePath, with: .string(rewritten))
    }

    private func value(in root: JsonValue, at path: [JsonPathComponent]) throws -> JsonValue {
        if path.isEmpty { return root }

        guard let head = path.first else {
            throw JsonEditError.pathNotFound
        }
        let tail = Array(path.dropFirst())

        switch (root, head) {
        case (.object(let items), .key(let key)):
            guard let child = items.first(where: { $0.0 == key })?.1 else { throw JsonEditError.pathNotFound }
            return try value(in: child, at: tail)
        case (.array(let items), .index(let index)):
            guard items.indices.contains(index) else { throw JsonEditError.pathNotFound }
            return try value(in: items[index], at: tail)
        default:
            throw JsonEditError.pathNotFound
        }
    }

    private func replacingValue(in root: JsonValue, at path: [JsonPathComponent], with newValue: JsonValue) throws -> JsonValue {
        if path.isEmpty { return newValue }

        guard let head = path.first else {
            throw JsonEditError.pathNotFound
        }
        let tail = Array(path.dropFirst())

        switch (root, head) {
        case (.object(var items), .key(let key)):
            guard let index = items.firstIndex(where: { $0.0 == key }) else { throw JsonEditError.pathNotFound }
            let replaced = try replacingValue(in: items[index].1, at: tail, with: newValue)
            items[index].1 = replaced
            return .object(items)

        case (.array(var items), .index(let index)):
            guard items.indices.contains(index) else { throw JsonEditError.pathNotFound }
            let replaced = try replacingValue(in: items[index], at: tail, with: newValue)
            items[index] = replaced
            return .array(items)

        default:
            throw JsonEditError.pathNotFound
        }
    }

    private func renameObjectKey(
        in root: inout JsonValue,
        parentPath: [JsonPathComponent],
        oldKey: String,
        newKey: String
    ) throws {
        var parent = try value(in: root, at: parentPath)
        guard case .object(var items) = parent else {
            throw JsonEditError.invalidOperation("Only object entries can be renamed")
        }

        guard let index = items.firstIndex(where: { $0.0 == oldKey }) else {
            throw JsonEditError.pathNotFound
        }

        if oldKey != newKey, items.contains(where: { $0.0 == newKey }) {
            throw JsonEditError.invalidOperation("Key already exists")
        }

        let value = items[index].1
        items[index] = (newKey, value)
        parent = .object(items)
        root = try replacingValue(in: root, at: parentPath, with: parent)
    }

    private func insertObjectEntry(in root: inout JsonValue, at path: [JsonPathComponent]) throws {
        var parent = try value(in: root, at: path)
        guard case .object(var items) = parent else {
            throw JsonEditError.invalidOperation("Sibling can only be added under object/array")
        }

        let key = uniqueKey(in: items.map { $0.0 }, preferred: "newKey")
        items.append((key, .null))
        parent = .object(items)
        root = try replacingValue(in: root, at: path, with: parent)
    }

    private func insertArrayValue(in root: inout JsonValue, at path: [JsonPathComponent], after index: Int) throws {
        var parent = try value(in: root, at: path)
        guard case .array(var items) = parent else {
            throw JsonEditError.invalidOperation("Sibling can only be added under object/array")
        }

        let insertion = min(max(index + 1, 0), items.count)
        items.insert(.null, at: insertion)
        parent = .array(items)
        root = try replacingValue(in: root, at: path, with: parent)
    }

    private func uniqueKey(in keys: [String], preferred: String) -> String {
        if !keys.contains(preferred) { return preferred }
        var index = 1
        while keys.contains("\(preferred)\(index)") {
            index += 1
        }
        return "\(preferred)\(index)"
    }
}
