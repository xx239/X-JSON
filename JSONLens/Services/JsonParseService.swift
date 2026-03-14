import Foundation

final class JsonParseService {
    func parse(text: String) -> Result<JsonValue, JsonParseError> {
        let strictResult = parseStrict(text: text)
        switch strictResult {
        case .success:
            return strictResult
        case .failure(let strictError):
            guard let normalized = Self.normalizeUnquotedObjectKeys(in: text), normalized != text else {
                return .failure(strictError)
            }
            switch parseStrict(text: normalized) {
            case .success(let value):
                return .success(value)
            case .failure:
                return .failure(strictError)
            }
        }
    }

    private func parseStrict(text: String) -> Result<JsonValue, JsonParseError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(JsonParseError(reason: "Empty input", line: 1, column: 1))
        }

        guard let data = text.data(using: .utf8) else {
            return .failure(JsonParseError(reason: "Input is not valid UTF-8", line: 1, column: 1))
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            guard object is [String: Any] || object is [Any] else {
                let location = Self.firstNonWhitespaceLineAndColumn(in: text)
                let context = Self.contextSnippet(in: text, line: location.line, column: location.column)
                return .failure(
                    JsonParseError(
                        reason: "Root must be object or array",
                        line: location.line,
                        column: location.column,
                        contextLine: context?.line,
                        caretColumn: context?.caretColumn
                    )
                )
            }
            return .success(try Self.fromAny(object))
        } catch {
            return .failure(Self.parseError(from: error, source: text))
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
        let reason = (nsError.userInfo["NSDebugDescription"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " around line [0-9]+, column [0-9]+\\.", with: "", options: .regularExpression)
            ?? nsError.localizedDescription

        let index = nsError.userInfo["NSJSONSerializationErrorIndex"] as? Int
        if let index {
            let location = Self.lineAndColumn(in: source, utf16Index: index)
            let context = Self.contextSnippet(in: source, line: location.line, column: location.column)
            return JsonParseError(
                reason: reason,
                line: location.line,
                column: location.column,
                contextLine: context?.line,
                caretColumn: context?.caretColumn
            )
        }
        return JsonParseError(reason: reason, line: 1, column: 1)
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

    private static func firstNonWhitespaceLineAndColumn(in text: String) -> (line: Int, column: Int) {
        var line = 1
        var column = 1

        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if scalar == "\n" {
                    line += 1
                    column = 1
                } else {
                    column += 1
                }
                continue
            }
            return (line, column)
        }
        return (1, 1)
    }

    private static func contextSnippet(
        in text: String,
        line: Int,
        column: Int,
        maxWidth: Int = 140
    ) -> (line: String, caretColumn: Int)? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.indices.contains(max(0, line - 1)) else { return nil }

        let rawLine = String(lines[line - 1])
        guard rawLine.count > maxWidth else {
            let caretColumn = max(1, min(column, rawLine.count + 1))
            return (rawLine, caretColumn)
        }

        let target = max(1, min(column, rawLine.count + 1))
        let half = maxWidth / 2

        var start = max(1, target - half)
        let end = min(rawLine.count, start + maxWidth - 1)
        if end - start + 1 < maxWidth {
            start = max(1, end - maxWidth + 1)
        }

        let startIndex = rawLine.index(rawLine.startIndex, offsetBy: start - 1)
        let endIndex = rawLine.index(rawLine.startIndex, offsetBy: end)
        let segment = String(rawLine[startIndex..<endIndex])

        let hasLeftEllipsis = start > 1
        let hasRightEllipsis = end < rawLine.count
        let displayLine = (hasLeftEllipsis ? "…" : "") + segment + (hasRightEllipsis ? "…" : "")
        let caretColumn = (target - start + 1) + (hasLeftEllipsis ? 1 : 0)
        return (displayLine, max(1, caretColumn))
    }

    private static let unquotedObjectKeyRegex: NSRegularExpression = {
        let pattern = #"([\{,]\s*)([A-Za-z_\$][A-Za-z0-9_\$]*|[0-9]+)(\s*:)"#
        return try! NSRegularExpression(pattern: pattern, options: [])
    }()

    private static func normalizeUnquotedObjectKeys(in text: String) -> String? {
        var result = ""
        var outsideBuffer = ""
        var inString = false
        var escaped = false
        var changed = false

        func flushOutsideBuffer() {
            guard !outsideBuffer.isEmpty else { return }
            let normalized = normalizeOutsideStringSegment(outsideBuffer, didChange: &changed)
            result.append(normalized)
            outsideBuffer.removeAll(keepingCapacity: true)
        }

        for char in text {
            if inString {
                result.append(char)
                if escaped {
                    escaped = false
                    continue
                }
                if char == "\\" {
                    escaped = true
                    continue
                }
                if char == "\"" {
                    inString = false
                }
            } else if char == "\"" {
                flushOutsideBuffer()
                inString = true
                result.append(char)
            } else {
                outsideBuffer.append(char)
            }
        }
        flushOutsideBuffer()

        return changed ? result : nil
    }

    private static func normalizeOutsideStringSegment(_ segment: String, didChange: inout Bool) -> String {
        let ns = NSMutableString(string: segment)
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = unquotedObjectKeyRegex.matches(in: segment, options: [], range: fullRange)
        guard !matches.isEmpty else { return segment }

        for match in matches.reversed() {
            guard match.numberOfRanges == 4 else { continue }
            let prefix = ns.substring(with: match.range(at: 1))
            let key = ns.substring(with: match.range(at: 2))
            let suffix = ns.substring(with: match.range(at: 3))
            let replacement = "\(prefix)\"\(key)\"\(suffix)"
            ns.replaceCharacters(in: match.range, with: replacement)
            didChange = true
        }

        return ns as String
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
