import Foundation

enum MainContentMode: String, Codable {
    case tree
    case text
}

struct JsonParseError: Error, Equatable {
    var reason: String
    var line: Int
    var column: Int

    var message: String {
        "\(reason) (line \(line), column \(column))"
    }
}

struct TabSnapshot {
    var rawText: String
    var rootValue: JsonValue?
    var parseError: JsonParseError?
    var isDirty: Bool
    var expandedEmbeddedNodeIDs: Set<String>
    var expandedNodeIDs: Set<String>
    var isTextMinified: Bool
}

struct TabSession: Identifiable {
    var id: UUID = UUID()
    var title: String
    var rawText: String = ""
    var rootValue: JsonValue?
    var parseError: JsonParseError?
    var mode: MainContentMode = .tree
    var treeNodes: [JsonNode] = []
    var selectedNodeID: String?
    var statusText: String = "Ready"
    var isDirty: Bool = false
    var expandedEmbeddedNodeIDs: Set<String> = []
    var expandedNodeIDs: Set<String> = []
    var searchQuery: String = ""
    var searchMatchedNodeIDs: [String] = []
    var textSearchMatchRanges: [NSRange] = []
    var searchCurrentMatchIndex: Int = 0
    var isTextMinified: Bool = false
    var undoStack: [TabSnapshot] = []
    var redoStack: [TabSnapshot] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    static func empty(named name: String = "Untitled") -> TabSession {
        TabSession(title: name)
    }

    func makeSnapshot() -> TabSnapshot {
        TabSnapshot(
            rawText: rawText,
            rootValue: rootValue,
            parseError: parseError,
            isDirty: isDirty,
            expandedEmbeddedNodeIDs: expandedEmbeddedNodeIDs,
            expandedNodeIDs: expandedNodeIDs,
            isTextMinified: isTextMinified
        )
    }

    mutating func apply(snapshot: TabSnapshot) {
        rawText = snapshot.rawText
        rootValue = snapshot.rootValue
        parseError = snapshot.parseError
        isDirty = snapshot.isDirty
        expandedEmbeddedNodeIDs = snapshot.expandedEmbeddedNodeIDs
        expandedNodeIDs = snapshot.expandedNodeIDs
        isTextMinified = snapshot.isTextMinified
    }
}
