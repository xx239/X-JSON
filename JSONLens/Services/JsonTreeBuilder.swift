import Foundation

final class JsonTreeBuilder {
    private let detector: EmbeddedJsonDetector

    init(detector: EmbeddedJsonDetector) {
        self.detector = detector
    }

    func buildTree(
        from root: JsonValue,
        maxEmbeddedDepth: Int,
        expandedEmbeddedNodeIDs: Set<String>
    ) -> [JsonNode] {
        let rootLocation = JsonNodeLocation(basePath: [], embeddedPath: [])
        let rootNode = buildNode(
            value: root,
            key: nil,
            location: rootLocation,
            source: .native,
            depth: 0,
            embeddedDepth: 0,
            maxEmbeddedDepth: maxEmbeddedDepth,
            expandedEmbeddedNodeIDs: expandedEmbeddedNodeIDs
        )
        return [rootNode]
    }

    private func buildNode(
        value: JsonValue,
        key: String?,
        location: JsonNodeLocation,
        source: JsonNodeSource,
        depth: Int,
        embeddedDepth: Int,
        maxEmbeddedDepth: Int,
        expandedEmbeddedNodeIDs: Set<String>
    ) -> JsonNode {
        let baseExpanded = depth <= 2

        switch value {
        case .object(let items):
            let children = items.map { childKey, childValue in
                let childLocation = append(.key(childKey), to: location, source: source)
                return buildNode(
                    value: childValue,
                    key: childKey,
                    location: childLocation,
                    source: source,
                    depth: depth + 1,
                    embeddedDepth: embeddedDepth,
                    maxEmbeddedDepth: maxEmbeddedDepth,
                    expandedEmbeddedNodeIDs: expandedEmbeddedNodeIDs
                )
            }
            return JsonNode(
                location: location,
                key: key,
                type: .object,
                source: source,
                displayValue: "Object",
                rawValue: value,
                childCount: items.count,
                isExpandedByDefault: baseExpanded,
                canExpandEmbedded: false,
                children: children
            )

        case .array(let items):
            let children = items.enumerated().map { index, childValue in
                let childLocation = append(.index(index), to: location, source: source)
                return buildNode(
                    value: childValue,
                    key: "[\(index)]",
                    location: childLocation,
                    source: source,
                    depth: depth + 1,
                    embeddedDepth: embeddedDepth,
                    maxEmbeddedDepth: maxEmbeddedDepth,
                    expandedEmbeddedNodeIDs: expandedEmbeddedNodeIDs
                )
            }
            let autoExpand = depth <= 1 && items.count <= 20
            return JsonNode(
                location: location,
                key: key,
                type: .array,
                source: source,
                displayValue: "Array",
                rawValue: value,
                childCount: items.count,
                isExpandedByDefault: autoExpand,
                canExpandEmbedded: false,
                children: children
            )

        case .string(let text):
            let embeddedValue = detector.parseEmbedded(text)
            let canExpand = embeddedValue != nil && embeddedDepth < maxEmbeddedDepth
            let shouldExpand = canExpand && (embeddedDepth == 0 || expandedEmbeddedNodeIDs.contains(location.id))
            var children: [JsonNode] = []
            if shouldExpand, let embeddedValue {
                let embeddedRootLocation = JsonNodeLocation(basePath: location.basePath, embeddedPath: location.embeddedPath)
                let embeddedNode = buildNode(
                    value: embeddedValue,
                    key: "Embedded",
                    location: embeddedRootLocation,
                    source: .embedded,
                    depth: depth + 1,
                    embeddedDepth: embeddedDepth + 1,
                    maxEmbeddedDepth: maxEmbeddedDepth,
                    expandedEmbeddedNodeIDs: expandedEmbeddedNodeIDs
                )
                children = embeddedNode.children
            }
            return JsonNode(
                location: location,
                key: key,
                type: .string,
                source: source,
                displayValue: text.count > 120 ? String(text.prefix(120)) + "…" : text,
                rawValue: value,
                childCount: children.count,
                isExpandedByDefault: false,
                canExpandEmbedded: canExpand,
                children: children
            )

        case .number, .boolean, .null:
            return JsonNode(
                location: location,
                key: key,
                type: value.type,
                source: source,
                displayValue: value.shortDisplay,
                rawValue: value,
                childCount: 0,
                isExpandedByDefault: false,
                canExpandEmbedded: false,
                children: []
            )
        }
    }

    private func append(_ component: JsonPathComponent, to location: JsonNodeLocation, source: JsonNodeSource) -> JsonNodeLocation {
        if source == .native && location.embeddedPath.isEmpty {
            return JsonNodeLocation(basePath: location.basePath + [component], embeddedPath: [])
        }
        return JsonNodeLocation(basePath: location.basePath, embeddedPath: location.embeddedPath + [component])
    }
}
