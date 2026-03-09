import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        MainWindowContentView(manager: appState.tabManager)
            .environmentObject(appState)
    }
}

private struct MainWindowContentView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var manager: TabSessionManager
    @FocusState private var isSearchFieldFocused: Bool
    @State private var isInspectorVisible: Bool = false
    @State private var inspectorWidthRatio: CGFloat = 0.3
    @State private var dividerDragStartWidth: CGFloat?

    private var activeTab: TabSession? { manager.activeTab }
    private var editorFontSize: CGFloat { CGFloat(appState.settings.editorFontSize) }

    var body: some View {
        VStack(spacing: 0) {
            TabBarView(
                tabs: manager.tabs,
                activeTabID: manager.activeTabID,
                onSelect: manager.selectTab,
                onClose: manager.closeTab,
                onNew: { manager.newTab(select: true) },
                onRename: manager.renameTab,
                allowDoubleClickRename: appState.settings.doubleClickToEdit
            )

            ToolbarView(
                mode: activeTab?.mode ?? .tree,
                onPasteParse: appState.pasteAndParse,
                onMinify: manager.performMinifyAction,
                minifyTitle: manager.activeMinifyButtonTitle,
                isInspectorVisible: isInspectorVisible,
                onToggleInspector: { isInspectorVisible.toggle() },
                onTreeMode: { manager.setMode(.tree) },
                onTextMode: { manager.setMode(.text) },
                onOpenSettingsFallback: appState.showSettingsWindowLegacy
            )

            if manager.isSearchBarVisible {
                searchBar
            }

            content

            StatusBarView(
                status: activeTab?.statusText ?? "Ready",
                isDirty: activeTab?.isDirty ?? false,
                mode: activeTab?.mode ?? .tree,
                tabCount: manager.tabs.count
            )
        }
        .background(Color.white)
        .overlay(alignment: .topTrailing) {
            if let toast = appState.toast {
                ClipboardToastView(toast: toast) {
                    appState.windowCoordinator.activateMainWindow()
                    manager.selectLastTab()
                    appState.consumeToast()
                }
                .padding(.top, 14)
                .padding(.trailing, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: appState.toast?.id)
        .onChange(of: appState.toast?.id) { _ in
            guard appState.toast != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                appState.consumeToast()
            }
        }
        .onChange(of: manager.isSearchBarVisible) { visible in
            if visible {
                DispatchQueue.main.async {
                    isSearchFieldFocused = true
                }
            } else {
                isSearchFieldFocused = false
            }
        }
        .onChange(of: isSearchFieldFocused) { focused in
            manager.setSearchFieldFocused(focused)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let tab = activeTab {
            if isInspectorVisible {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        mainContentPane(tab)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        resizeDivider(totalWidth: geo.size.width)

                        inspectorPane
                            .frame(width: clampedInspectorWidth(totalWidth: geo.size.width))
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainContentPane(tab)
            }
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private func mainContentPane(_ tab: TabSession) -> some View {
        Group {
            if isEmptyState(tab) {
                emptyState
            } else if tab.mode == .tree {
                JsonTreeView(
                    nodes: tab.treeNodes,
                    selection: manager.activeTab?.selectedNodeID,
                    expandedNodeIDs: manager.activeTab?.expandedNodeIDs ?? [],
                    matchedNodeIDs: manager.activeSearchMatchedNodeIDs,
                    keyColor: Color(hex: appState.settings.appearanceTheme.treeKeyHexColor) ?? .primary,
                    valueColor: Color(hex: appState.settings.appearanceTheme.treeValueHexColor) ?? .secondary,
                    fontFamily: appState.settings.editorFontFamily,
                    fontSize: editorFontSize,
                    onSelectionChange: manager.selectNode,
                    onExpandedNodeIDsChange: manager.setExpandedNodeIDs,
                    onInlineKeyEdit: manager.applyInlineKeyEdit,
                    onInlineValueEdit: manager.applyInlineValueEdit,
                    onAddSibling: manager.addSiblingForSelectedNode,
                    onAddChild: manager.addChildForSelectedNode,
                    onDelete: manager.deleteSelectedNode,
                    onExpandEmbedded: manager.expandEmbeddedForSelectedNode
                )
            } else {
                JsonTextEditorView(
                    text: rawTextBinding,
                    parseError: tab.parseError,
                    searchQuery: manager.activeSearchQuery,
                    searchMatchRanges: manager.activeTextSearchMatchRanges,
                    selectedSearchMatchIndex: manager.activeTextSearchCurrentIndex,
                    fontFamily: appState.settings.editorFontFamily,
                    fontSize: editorFontSize,
                    onSyncToTree: manager.syncTextToTree
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private var inspectorPane: some View {
        InspectorPanelView(
            node: manager.selectedNode(),
            fontFamily: appState.settings.editorFontFamily,
            fontSize: editorFontSize,
            onApply: { valueText, type, maybeKey in
                manager.applyEditOnSelectedNode(
                    newValueText: valueText,
                    targetType: type,
                    maybeNewKey: maybeKey
                )
            },
            onAddSibling: manager.addSiblingForSelectedNode,
            onAddChild: manager.addChildForSelectedNode,
            onDelete: manager.deleteSelectedNode
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func resizeDivider(totalWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 6)
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(0.14))
                    .frame(width: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if dividerDragStartWidth == nil {
                            dividerDragStartWidth = clampedInspectorWidth(totalWidth: totalWidth)
                        }
                        guard let startWidth = dividerDragStartWidth else { return }
                        let proposed = startWidth - value.translation.width
                        let clampedWidth = clamped(proposed, totalWidth: totalWidth)
                        inspectorWidthRatio = clampedWidth / max(totalWidth, 1)
                    }
                    .onEnded { _ in
                        dividerDragStartWidth = nil
                    }
            )
    }

    private func clampedInspectorWidth(totalWidth: CGFloat) -> CGFloat {
        clamped(inspectorWidthRatio * totalWidth, totalWidth: totalWidth)
    }

    private func clamped(_ width: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let minWidth: CGFloat = 240
        let maxWidth = max(minWidth, totalWidth * 0.55)
        return min(max(width, minWidth), maxWidth)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search key/value/path", text: searchQueryBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .focused($isSearchFieldFocused)
                .onSubmit {
                    manager.findNextSearchMatch()
                }

            Text("\(manager.activeSearchMatchPosition)/\(manager.activeSearchMatchCount)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .trailing)

            Button("Next") {
                manager.findNextSearchMatch()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11, weight: .semibold))

            Button {
                manager.hideSearchBar()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.35)
        }
    }

    private var searchQueryBinding: Binding<String> {
        Binding(
            get: { manager.activeSearchQuery },
            set: { manager.updateSearchQuery($0) }
        )
    }

    private var rawTextBinding: Binding<String> {
        Binding(
            get: { manager.activeTab?.rawText ?? "" },
            set: { manager.updateRawText($0) }
        )
    }

    private func isEmptyState(_ tab: TabSession) -> Bool {
        tab.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && tab.rootValue == nil
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Paste JSON to start parsing")
                .font(.system(size: 20, weight: .semibold))

            Text("Supports clipboard detection, embedded JSON expansion, and structured editing")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("Paste and Parse") {
                    appState.pasteAndParse()
                }
                .buttonStyle(.borderedProminent)

                Button(appState.settings.enableClipboardMonitoring ? "Clipboard Monitoring Enabled" : "Enable Clipboard Monitoring") {
                    appState.settings.enableClipboardMonitoring = true
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self = Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}
