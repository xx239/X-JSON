import Foundation

final class JsonParseService {
    func parse(text: String) -> Result<JsonValue, JsonParseError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(JsonParseError(reason: "Empty input", line: 1, column: 1))
        }

        guard let data = trimmed.data(using: .utf8) else {
            return .failure(JsonParseError(reason: "Input is not valid UTF-8", line: 1, column: 1))
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            guard object is [String: Any] || object is [Any] else {
                return .failure(JsonParseError(reason: "Root must be object or array", line: 1, column: 1))
            }
            return .success(try Self.fromAny(object))
        } catch {
            return .failure(Self.parseError(from: error, source: trimmed))
        }
    }

    func format(text: String) -> Result<String, JsonParseError> {
        switch parse(text: text) {
        case .success(let value):
            do {
                return .success(try stringify(value: value, pretty: true))
            } catch {
                return .failure(JsonParseError(reason: "Failed to format JSON", line: 1, column: 1))
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    func minify(text: String) -> Result<String, JsonParseError> {
        switch parse(text: text) {
        case .success(let value):
            do {
                return .success(try stringify(value: value, pretty: false))
            } catch {
                return .failure(JsonParseError(reason: "Failed to minify JSON", line: 1, column: 1))
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    func stringify(value: JsonValue, pretty: Bool) throws -> String {
        let object = Self.toAny(value)
        let options: JSONSerialization.WritingOptions = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        let data = try JSONSerialization.data(withJSONObject: object, options: options)
        return String(decoding: data, as: UTF8.self)
    }

    private static func parseError(from error: Error, source: String) -> JsonParseError {
        let nsError = error as NSError
        let index = nsError.userInfo["NSJSONSerializationErrorIndex"] as? Int
        if let index {
            let location = Self.lineAndColumn(in: source, utf16Index: index)
            return JsonParseError(reason: nsError.localizedDescription, line: location.line, column: location.column)
        }
        return JsonParseError(reason: nsError.localizedDescription, line: 1, column: 1)
    }

    private static func lineAndColumn(in text: String, utf16Index: Int) -> (line: Int, column: Int) {
        if utf16Index <= 0 {
            return (1, 1)
        }

        var consumed = 0
        var line = 1
        var column = 1
        for scalar in text.unicodeScalars {
            if consumed >= utf16Index { break }
            consumed += scalar.utf16.count
            if scalar == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }
        return (line, max(1, column - 1))
    }

    static func fromAny(_ value: Any) throws -> JsonValue {
        if let dict = value as? [String: Any] {
            let keys = dict.keys.sorted()
            let items = try keys.map { key in
                (key, try fromAny(dict[key] as Any))
            }
            return .object(items)
        }

        if let array = value as? [Any] {
            return .array(try array.map { try fromAny($0) })
        }

        if let string = value as? String {
            return .string(string)
        }

        if let number = value as? NSNumber {
            let typeID = CFGetTypeID(number)
            if typeID == CFBooleanGetTypeID() {
                return .boolean(number.boolValue)
            }
            return .number(number.doubleValue)
        }

        if value is NSNull {
            return .null
        }

        throw NSError(domain: "JsonParseService", code: 1)
    }

    static func toAny(_ value: JsonValue) -> Any {
        switch value {
        case .object(let items):
            return Dictionary(uniqueKeysWithValues: items.map { ($0.0, toAny($0.1)) })
        case .array(let items):
            return items.map { toAny($0) }
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .boolean(let value):
            return value
        case .null:
            return NSNull()
        }
    }
}
