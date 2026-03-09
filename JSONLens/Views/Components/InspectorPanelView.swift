import SwiftUI

struct InspectorPanelView: View {
    let node: JsonNode?
    let fontFamily: AppFontFamily
    let fontSize: CGFloat
    let onApply: (_ valueText: String, _ type: JsonNodeType, _ maybeKey: String?) -> Void
    let onAddSibling: () -> Void
    let onAddChild: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Inspector")
                .font(.system(size: 15, weight: .semibold))

            if let node {
                InspectorEditorSection(
                    node: node,
                    fontFamily: fontFamily,
                    fontSize: fontSize,
                    onApply: onApply,
                    onAddSibling: onAddSibling,
                    onAddChild: onAddChild,
                    onDelete: onDelete
                )
                .id(refreshToken(for: node))
            } else {
                Text("Select a node to inspect and edit details.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func refreshToken(for node: JsonNode) -> String {
        [
            node.id,
            node.key ?? "",
            node.type.rawValue,
            node.displayValue,
            String(node.childCount)
        ].joined(separator: "|")
    }
}

private struct InspectorEditorSection: View {
    let node: JsonNode
    let fontFamily: AppFontFamily
    let fontSize: CGFloat
    let onApply: (_ valueText: String, _ type: JsonNodeType, _ maybeKey: String?) -> Void
    let onAddSibling: () -> Void
    let onAddChild: () -> Void
    let onDelete: () -> Void

    @State private var keyDraft: String
    @State private var valueDraft: String
    @State private var selectedType: JsonNodeType

    init(
        node: JsonNode,
        fontFamily: AppFontFamily,
        fontSize: CGFloat,
        onApply: @escaping (_ valueText: String, _ type: JsonNodeType, _ maybeKey: String?) -> Void,
        onAddSibling: @escaping () -> Void,
        onAddChild: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.node = node
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.onApply = onApply
        self.onAddSibling = onAddSibling
        self.onAddChild = onAddChild
        self.onDelete = onDelete
        _keyDraft = State(initialValue: node.key ?? "")
        _valueDraft = State(initialValue: Self.rawValueText(node.rawValue))
        _selectedType = State(initialValue: node.type)
    }

    var body: some View {
        Group {
            field("Path") {
                Text(node.location.displayPath)
                    .font(AppTypography.monoFont(family: fontFamily, size: fontSize))
                    .lineLimit(nil)
                    .foregroundStyle(.primary)
            }

            if node.key != nil {
                field("Key") {
                    TextField("Key", text: $keyDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoFont(family: fontFamily, size: fontSize + 1))
                }
            }

            field("Type") {
                Picker("Type", selection: $selectedType) {
                    ForEach(JsonNodeType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .font(AppTypography.monoFont(family: fontFamily, size: fontSize + 1))
            }

            field("Value") {
                if node.type == .object || node.type == .array {
                    Text("Use structured editing for container nodes.")
                        .font(AppTypography.monoFont(family: fontFamily, size: fontSize))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                }

                TextEditor(text: $valueDraft)
                    .font(AppTypography.monoFont(family: fontFamily, size: fontSize + 1))
                    .frame(minHeight: 94, maxHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.14), lineWidth: 1)
                    )
            }

            field("Actions") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button("Apply") {
                            onApply(valueDraft, selectedType, node.key != nil ? keyDraft : nil)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    HStack(spacing: 8) {
                        Button("Add Sibling") {
                            onAddSibling()
                        }
                        .buttonStyle(.bordered)

                        Button("Add Child") {
                            onAddChild()
                        }
                        .buttonStyle(.bordered)

                        Button("Delete") {
                            onDelete()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            }
        }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private static func rawValueText(_ value: JsonValue) -> String {
        switch value {
        case .object:
            return "{}"
        case .array:
            return "[]"
        case .string(let text):
            return text
        case .number(let number):
            return String(number)
        case .boolean(let bool):
            return bool ? "true" : "false"
        case .null:
            return "null"
        }
    }
}
