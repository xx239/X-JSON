import AppKit
import SwiftUI

struct JsonTreeView: View {
    let nodes: [JsonNode]
    let selection: String?
    let expandedNodeIDs: Set<String>
    let matchedNodeIDs: Set<String>
    let keyColor: Color
    let valueColor: Color
    let fontFamily: AppFontFamily
    let fontSize: CGFloat
    let onSelectionChange: (String?) -> Void
    let onExpandedNodeIDsChange: (Set<String>) -> Void
    let onInlineKeyEdit: (String, String) -> Void
    let onInlineValueEdit: (String, String) -> Void
    let onAddSibling: () -> Void
    let onAddChild: () -> Void
    let onDelete: () -> Void
    let onExpandEmbedded: () -> Void

    @State private var internalSelection: String?
    @State private var internalExpandedNodeIDs: Set<String> = []
    @State private var editingKeyNodeID: String?
    @State private var editingValueNodeID: String?
    @State private var keyDraft: String = ""
    @State private var valueDraft: String = ""

    @FocusState private var focusedField: InlineField?

    private enum InlineField: Hashable {
        case key(String)
        case value(String)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visibleRows) { row in
                        rowView(row)
                            .id(row.id)
                            .contextMenu {
                                Button("Copy Path") {
                                    commitAndBlurInlineEdits()
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(row.node.location.displayPath, forType: .string)
                                }

                                Divider()

                                Button("Add Sibling") {
                                    commitAndBlurInlineEdits()
                                    internalSelection = row.node.id
                                    onAddSibling()
                                }

                                Button("Add Child") {
                                    commitAndBlurInlineEdits()
                                    internalSelection = row.node.id
                                    onAddChild()
                                }

                                Button("Delete") {
                                    commitAndBlurInlineEdits()
                                    internalSelection = row.node.id
                                    onDelete()
                                }

                                if row.node.canExpandEmbedded {
                                    Divider()
                                    Button("Expand Embedded JSON") {
                                        commitAndBlurInlineEdits()
                                        internalSelection = row.node.id
                                        onExpandEmbedded()
                                    }
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
            }
            .background(Color.clear)
            .simultaneousGesture(
                TapGesture().onEnded {
                    handleBackgroundTap()
                }
            )
            .onAppear {
                internalSelection = selection
                internalExpandedNodeIDs = expandedNodeIDs
                scrollToSelectionIfNeeded(proxy)
            }
            .onDisappear {
                commitAndBlurInlineEdits()
            }
            .onChange(of: selection) { newValue in
                if internalSelection != newValue {
                    internalSelection = newValue
                }
                scrollToSelectionIfNeeded(proxy)
            }
            .onChange(of: expandedNodeIDs) { newValue in
                if internalExpandedNodeIDs != newValue {
                    internalExpandedNodeIDs = newValue
                }
                DispatchQueue.main.async {
                    scrollToSelectionIfNeeded(proxy)
                }
            }
            .onChange(of: internalSelection) { newValue in
                guard newValue != selection else { return }
                DispatchQueue.main.async {
                    onSelectionChange(newValue)
                }
                scrollToSelectionIfNeeded(proxy)
            }
            .onChange(of: internalExpandedNodeIDs) { newValue in
                guard newValue != expandedNodeIDs else { return }
                DispatchQueue.main.async {
                    onExpandedNodeIDsChange(newValue)
                }
            }
            .onChange(of: focusedField) { focused in
                if focused == nil {
                    commitInlineEditsIfNeeded()
                }
            }
        }
    }

    private var visibleRows: [TreeRow] {
        var rows: [TreeRow] = []

        func append(_ node: JsonNode, depth: Int) {
            rows.append(TreeRow(node: node, depth: depth))
            if !node.children.isEmpty, internalExpandedNodeIDs.contains(node.id) {
                for child in node.children {
                    append(child, depth: depth + 1)
                }
            }
        }

        for node in nodes {
            append(node, depth: 0)
        }

        return rows
    }

    @ViewBuilder
    private func rowView(_ row: TreeRow) -> some View {
        let node = row.node
        let isSelected = internalSelection == node.id
        let isMatched = matchedNodeIDs.contains(node.id)
        let hasChildren = !node.children.isEmpty
        let isExpanded = internalExpandedNodeIDs.contains(node.id)
        let keyEditing = editingKeyNodeID == node.id
        let valueEditing = editingValueNodeID == node.id

        HStack(spacing: 8) {
            HStack(spacing: 8) {
                if hasChildren {
                    Button {
                        toggleExpand(for: node.id)
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(AppTypography.monoFont(family: fontFamily, size: max(10, fontSize - 2), weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 12)
                }

                if keyEditing {
                    TextField("Key", text: $keyDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoFont(family: fontFamily, size: fontSize, weight: .medium))
                        .frame(minWidth: 90, maxWidth: 220)
                        .focused($focusedField, equals: .key(node.id))
                        .onSubmit {
                            commitKeyEdit(for: node.id)
                        }
                } else if let key = node.key {
                    Text(key)
                        .font(AppTypography.monoFont(family: fontFamily, size: fontSize, weight: .medium))
                        .foregroundStyle(keyColor)
                        .onTapGesture(count: 2) {
                            beginKeyEdit(for: node)
                        }
                } else {
                    Text("$")
                        .font(AppTypography.monoFont(family: fontFamily, size: fontSize, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(node.type.rawValue)
                    .font(AppTypography.monoFont(family: fontFamily, size: max(10, fontSize - 2), weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.08))
                    )

                if valueEditing {
                    TextField("Value", text: $valueDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoFont(family: fontFamily, size: fontSize))
                        .frame(minWidth: 120)
                        .focused($focusedField, equals: .value(node.id))
                        .onSubmit {
                            commitValueEdit(for: node.id)
                        }
                } else {
                    Text(node.displayValue)
                        .font(AppTypography.monoFont(family: fontFamily, size: fontSize))
                        .foregroundStyle(valueColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .onTapGesture(count: 2) {
                            beginValueEdit(for: node)
                        }
                }

                Spacer(minLength: 4)

                if node.childCount > 0 {
                    Text("\(node.childCount)")
                        .font(AppTypography.monoFont(family: fontFamily, size: max(10, fontSize - 1), weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, CGFloat(row.depth) * 16)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor(isSelected: isSelected, isMatched: isMatched))
        .contentShape(Rectangle())
        .onTapGesture {
            handleRowSelectionTap(nodeID: node.id)
        }
    }

    private func backgroundColor(isSelected: Bool, isMatched: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        }
        if isMatched {
            return Color.yellow.opacity(0.2)
        }
        return Color.clear
    }

    private func toggleExpand(for nodeID: String) {
        commitAndBlurInlineEdits()
        if internalExpandedNodeIDs.contains(nodeID) {
            internalExpandedNodeIDs.remove(nodeID)
        } else {
            internalExpandedNodeIDs.insert(nodeID)
        }
    }

    private func scrollToSelectionIfNeeded(_ proxy: ScrollViewProxy) {
        guard let target = internalSelection else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(target, anchor: .center)
        }
    }

    private func beginKeyEdit(for node: JsonNode) {
        guard node.key != nil else { return }
        if activeEditingNodeID != node.id {
            commitAndBlurInlineEdits()
        }
        internalSelection = node.id
        editingValueNodeID = nil
        editingKeyNodeID = node.id
        keyDraft = node.key ?? ""
        DispatchQueue.main.async {
            focusedField = .key(node.id)
        }
    }

    private func beginValueEdit(for node: JsonNode) {
        guard isInlineValueEditable(node) else { return }
        if activeEditingNodeID != node.id {
            commitAndBlurInlineEdits()
        }
        internalSelection = node.id
        editingKeyNodeID = nil
        editingValueNodeID = node.id
        valueDraft = rawValueText(node.rawValue)
        DispatchQueue.main.async {
            focusedField = .value(node.id)
        }
    }

    private func isInlineValueEditable(_ node: JsonNode) -> Bool {
        switch node.type {
        case .string, .number, .boolean, .null:
            return true
        case .object, .array:
            return false
        }
    }

    private func commitInlineEditsIfNeeded() {
        if let nodeID = editingKeyNodeID {
            commitKeyEdit(for: nodeID)
        }
        if let nodeID = editingValueNodeID {
            commitValueEdit(for: nodeID)
        }
    }

    private var activeEditingNodeID: String? {
        editingKeyNodeID ?? editingValueNodeID
    }

    private func handleRowSelectionTap(nodeID: String) {
        if let editingNodeID = activeEditingNodeID, editingNodeID != nodeID {
            commitAndBlurInlineEdits()
        }
        internalSelection = nodeID
    }

    private func handleBackgroundTap() {
        guard focusedField != nil else { return }
        commitAndBlurInlineEdits()
    }

    private func commitAndBlurInlineEdits() {
        commitInlineEditsIfNeeded()
        focusedField = nil
    }

    private func commitKeyEdit(for nodeID: String) {
        let draft = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !draft.isEmpty {
            onInlineKeyEdit(nodeID, draft)
        }
        editingKeyNodeID = nil
        if focusedField == .key(nodeID) {
            focusedField = nil
        }
    }

    private func commitValueEdit(for nodeID: String) {
        onInlineValueEdit(nodeID, valueDraft)
        editingValueNodeID = nil
        if focusedField == .value(nodeID) {
            focusedField = nil
        }
    }

    private func rawValueText(_ value: JsonValue) -> String {
        switch value {
        case .object:
            return "{}"
        case .array:
            return "[]"
        case .string(let text):
            return text
        case .number(let number):
            return String(number)
        case .boolean(let flag):
            return flag ? "true" : "false"
        case .null:
            return "null"
        }
    }
}

private struct TreeRow: Identifiable {
    let node: JsonNode
    let depth: Int

    var id: String { node.id }
}
