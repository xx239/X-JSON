import Foundation

final class EmbeddedJsonDetector {
    private let parser: JsonParseService

    init(parser: JsonParseService) {
        self.parser = parser
    }

    func parseEmbedded(_ text: String) -> JsonValue? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
                (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) else {
            return nil
        }

        switch parser.parse(text: trimmed) {
        case .success(let value):
            if case .object = value { return value }
            if case .array = value { return value }
            return nil
        case .failure:
            return nil
        }
    }
}
