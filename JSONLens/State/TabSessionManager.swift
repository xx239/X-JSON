import AppKit
import Foundation

@MainActor
final class TabSessionManager: ObservableObject {
    @Published var tabs: [TabSession] = [TabSession.empty()]
    @Published var activeTabID: UUID?
    @Published var isSearchBarVisible: Bool = false
    @Published var isSearchFieldFocused: Bool = false

    private let parser: JsonParseService
    private let treeBuilder: JsonTreeBuilder
    private let editor: JsonEditService
    private var settings: AppSettings

    init(
        parser: JsonParseService,
        treeBuilder: JsonTreeBuilder,
        editor: JsonEditService,
        settings: AppSettings
    ) {
        self.parser = parser
        self.treeBuilder = treeBuilder
        self.editor = editor
        self.settings = settings
        self.activeTabID = tabs.first?.id
    }

    var activeTab: TabSession? {
        guard let activeTabID else { return nil }
        return tabs.first(where: { $0.id == activeTabID })
    }

    var canUndo: Bool { activeTab?.canUndo == true }
    var canRedo: Bool { activeTab?.canRedo == true }
    var activeSearchQuery: String { activeTab?.searchQuery ?? "" }
    var activeSearchMatchCount: Int {
        guard let tab = activeTab else { return 0 }
        if tab.mode == .text {
            return tab.textSearchMatchRanges.count
        }
        return tab.searchMatchedNodeIDs.count
    }
    var activeSearchMatchPosition: Int {
        guard let tab = activeTab else { return 0 }
        let total = tab.mode == .text ? tab.textSearchMatchRanges.count : tab.searchMatchedNodeIDs.count
        guard total > 0 else { return 0 }
        return tab.searchCurrentMatchIndex + 1
    }
    var activeSearchMatchedNodeIDs: Set<String> {
        Set(activeTab?.searchMatchedNodeIDs ?? [])
    }
    var activeTextSearchMatchRanges: [NSRange] {
        guard let tab = activeTab, tab.mode == .text else { return [] }
        return tab.textSearchMatchRanges
    }
    var activeTextSearchCurrentIndex: Int {
        guard let tab = activeTab, tab.mode == .text else { return 0 }
        guard tab.searchCurrentMatchIndex >= 0 else { return 0 }
        return tab.searchCurrentMatchIndex
    }
    var activeMinifyButtonTitle: String {
        guard let tab = activeTab else { return "Minify" }
        if tab.mode == .tree {
            return tab.expandedNodeIDs.isEmpty ? "Expand All" : "Minify"
        }
        return tab.isTextMinified ? "Format" : "Minify"
    }

    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        for index in tabs.indices {
            guard let root = tabs[index].rootValue else { continue }
            var tab = tabs[index]
            tab.treeNodes = buildTree(for: root, expandedEmbeddedNodeIDs: tab.expandedEmbeddedNodeIDs)
            reconcileExpandedState(for: &tab)
            refreshSearchMatches(for: &tab)
            tabs[index] = tab
        }
    }

    func newTab(preferredName: String? = nil, select: Bool = true) {
        let base = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (base?.isEmpty == false) ? base! : "Untitled"
        let tab = TabSession.empty(named: name)
        tabs.append(tab)
        if select {
            activeTabID = tab.id
        }
    }

    func closeActiveTab() {
        guard let id = activeTabID else { return }
        closeTab(id)
    }

    func closeTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)

        if tabs.isEmpty {
            let fresh = TabSession.empty()
            tabs = [fresh]
            activeTabID = fresh.id
            return
        }

        if activeTabID == id {
            let fallback = min(index, tabs.count - 1)
            activeTabID = tabs[fallback].id
        }
    }

    func renameTab(_ id: UUID, to name: String) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        var tab = tabs[index]
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tab.title = trimmed.isEmpty ? tab.title : trimmed
        tabs[index] = tab
    }

    func selectTab(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    func selectLastTab() {
        guard let id = tabs.last?.id else { return }
        activeTabID = id
    }

    func showSearchBar() {
        isSearchBarVisible = true
    }

    func toggleSearchBar() {
        isSearchBarVisible.toggle()
        if !isSearchBarVisible {
            isSearchFieldFocused = false
            clearSearchStateForActiveTab(clearTreeSelection: true)
        }
    }

    func hideSearchBar() {
        isSearchBarVisible = false
        isSearchFieldFocused = false
        clearSearchStateForActiveTab(clearTreeSelection: true)
    }

    func setSearchFieldFocused(_ focused: Bool) {
        if isSearchFieldFocused == focused { return }
        isSearchFieldFocused = focused
    }

    func pasteFromCommandShortcut() {
        if isSearchFieldFocused, isSearchBarVisible {
            if !NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) {
                pasteIntoSearchQuery()
            }
            return
        }

        if shouldPasteIntoTextEditor {
            if !NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) {
                setStatusForActive("Unable to paste into text editor")
            }
            return
        }

        pasteAndParseFromPasteboard()
    }

    func performMinifyAction() {
        guard let currentTab = activeTab else { return }
        if currentTab.mode == .tree {
            toggleTreeExpansion()
        } else {
            if currentTab.isTextMinified {
                formatActiveJSON()
            } else {
                minifyActiveJSON()
            }
        }
    }

    func updateSearchQuery(_ query: String) {
        guard let index = activeIndex else { return }
        var tab = tabs[index]
        tab.searchQuery = query
        tab.searchCurrentMatchIndex = 0

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            tab.searchMatchedNodeIDs = []
            tab.textSearchMatchRanges = []
            tab.statusText = "Search cleared"
            tabs[index] = tab
            return
        }

        let lowered = trimmed.lowercased()
        tab.searchMatchedNodeIDs = collectSearchMatches(in: tab.treeNodes, loweredQuery: lowered)
        tab.textSearchMatchRanges = collectTextSearchMatches(in: tab.rawText, query: trimmed)

        if tab.mode == .text {
            guard !tab.textSearchMatchRanges.isEmpty else {
                tab.statusText = "No matches"
                tabs[index] = tab
                return
            }
            tab.statusText = "Match 1 / \(tab.textSearchMatchRanges.count)"
            tabs[index] = tab
            return
        }

        if tab.searchMatchedNodeIDs.isEmpty {
            tab.statusText = "No matches"
            tabs[index] = tab
            return
        }

        revealSearchMatch(in: &tab, at: 0)
        tabs[index] = tab
    }

    func findNextSearchMatch() {
        guard let index = activeIndex else { return }
        var tab = tabs[index]

        if tab.mode == .text {
            guard !tab.textSearchMatchRanges.isEmpty else { return }
            let next = (tab.searchCurrentMatchIndex + 1) % tab.textSearchMatchRanges.count
            tab.searchCurrentMatchIndex = next
            tab.statusText = "Match \(next + 1) / \(tab.textSearchMatchRanges.count)"
            tabs[index] = tab
            return
        }

        guard !tab.searchMatchedNodeIDs.isEmpty else { return }
        let next = (tab.searchCurrentMatchIndex + 1) % tab.searchMatchedNodeIDs.count
        revealSearchMatch(in: &tab, at: next)
        tabs[index] = tab
    }

    private func pasteIntoSearchQuery() {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        guard let index = activeIndex else { return }
        var tab = tabs[index]
        tab.searchQuery += text
        tabs[index] = tab
        updateSearchQuery(tab.searchQuery)
    }

    private var shouldPasteIntoTextEditor: Bool {
        guard activeTab?.mode == .text else { return false }
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSTextView
    }

    private func toggleTreeExpansion() {
        guard let index = activeIndex else { return }
        var tab = tabs[index]
        guard tab.mode == .tree else { return }

        if tab.expandedNodeIDs.isEmpty {
            expandAllTreeContent(for: &tab)
            tab.statusText = "Expanded all levels"
        } else {
            tab.expandedNodeIDs = []
            tab.statusText = "Collapsed all levels"
        }

        tabs[index] = tab
    }

    private func expandAllTreeContent(for tab: inout TabSession) {
        guard let root = tab.rootValue else { return }

        var expandedEmbedded = tab.expandedEmbeddedNodeIDs
        var latestTree = buildTree(for: root, expandedEmbeddedNodeIDs: expandedEmbedded)

        // Keep unfolding embedded JSON strings layer by layer until no new expandable node appears.
        for _ in 0..<(settings.embeddedJSONMaxDepth + 2) {
            let candidateIDs = expandableEmbeddedNodeIDs(in: latestTree)
            let merged = expandedEmbedded.union(candidateIDs)
            if merged == expandedEmbedded {
                break
            }
            expandedEmbedded = merged
            latestTree = buildTree(for: root, expandedEmbeddedNodeIDs: expandedEmbedded)
        }

        tab.expandedEmbeddedNodeIDs = expandedEmbedded
        tab.treeNodes = latestTree
        tab.expandedNodeIDs = allContainerNodeIDs(in: latestTree)
        refreshSearchMatches(for: &tab)
    }

    func handleClipboardJSON(_ text: String, isForeground: Bool) {
        let targetTabID: UUID
        if settings.openDetectedJSONInNewTab {
            targetTabID = createTabForIncomingJSON(preferredTitle: nextClipboardTabTitle())
        } else if let activeTabID {
            targetTabID = activeTabID
        } else {
            targetTabID = createTabForIncomingJSON(preferredTitle: nextClipboardTabTitle())
        }
        parseAndAttach(text: text, tabID: targetTabID, shouldSelect: isForeground)
    }

    func pasteAndParseFromPasteboard() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            setStatusForActive("Clipboard is empty")
            return
        }

        if shouldReuseCurrentEmptyTab {
            parseAndAttach(text: text, tabID: activeTabID, shouldSelect: true)
        } else {
            let id = createTabForIncomingJSON(preferredTitle: "Pasted")
            parseAndAttach(text: text, tabID: id, shouldSelect: true)
        }
    }

    func updateRawText(_ text: String) {
        guard let index = activeIndex else { return }
        var tab = tabs[index]
        tab.rawText = text
        tab.isDirty = true
        tab.isTextMinified = false
        tab.statusText = "Editing text"
        refreshSearchMatches(for: &tab)
        tabs[index] = tab
    }

    func syncTextToTree() {
        guard let index = activeIndex else { return }
        pushUndo(at: index)

        var tab = tabs[index]
        switch parser.parse(text: tab.rawText) {
        case .success(let root):
            tab.rootValue = root
            tab.parseError = nil
            tab.treeNodes = buildTree(for: root, expandedEmbeddedNodeIDs: tab.expandedEmbeddedNodeIDs)
            reconcileExpandedState(for: &tab)
            refreshSearchMatches(for: &tab)
            tab.mode = .tree
            tab.isTextMinified = false
            tab.statusText = "Synced text to tree"
            tab.isDirty = true
        case .failure(let error):
            tab.parseError = error
            tab.statusText = error.message
        }
        tabs[index] = tab
    }

    func formatActiveJSON() {
        guard let index = activeIndex else { return }
        guard !tabs[index].rawText.isEmpty else { return }

        pushUndo(at: index)
        var tab = tabs[index]
        switch parser.format(text: tab.rawText) {
        case .success(let formatted):
            tab.rawText = formatted
            tab.statusText = "Formatted"
            tab.parseError = nil
            if case .success(let parsed) = parser.parse(text: formatted) {
                tab.rootValue = parsed
                tab.treeNodes = buildTree(for: parsed, expandedEmbeddedNodeIDs: tab.expandedEmbeddedNodeIDs)
                reconcileExpandedState(for: &tab)
                refreshSearchMatches(for: &tab)
            }
            tab.isTextMinified = false
            tab.isDirty = true
        case .failure(let error):
            tab.parseError = error
            tab.statusText = error.message
        }
        tabs[index] = tab
    }

    func minifyActiveJSON() {
        guard let index = activeIndex else { return }
        guard !tabs[index].rawText.isEmpty else { return }

        pushUndo(at: index)
        var tab = tabs[index]
        switch parser.minify(text: tab.rawText) {
        case .success(let compact):
            tab.rawText = compact
            tab.statusText = "Minified"
            tab.parseError = nil
            if case .success(let parsed) = parser.parse(text: compact) {
                tab.rootValue = parsed
                tab.treeNodes = buildTree(for: parsed, expandedEmbeddedNodeIDs: tab.expandedEmbeddedNodeIDs)
                reconcileExpandedState(for: &tab)
                refreshSearchMatches(for: &tab)
            }
            tab.isTextMinified = true
            tab.isDirty = true
        case .failure(let error):
            tab.parseError = error
            tab.statusText = error.message
        }
        tabs[index] = tab
    }

    func setMode(_ mode: MainContentMode) {
        guard let index = activeIndex else { return }
        var tab = tabs[index]
        guard tab.mode != mode else { return }

        if mode == .tree, !syncTextToTreeForModeSwitch(&tab) {
            tabs[index] = tab
            return
        }

        tab.mode = mode
        refreshSearchMatches(for: &tab)
        tabs[index] = tab
    }

    func selectNode(_ id: String?) {
        guard let index = activeIndex else { return }
        var tab = tabs[index]
        if tab.selectedNodeID == id { return }
        tab.selectedNodeID = id
        tabs[index] = tab
    }

    func setExpandedNodeIDs(_ ids: Set<String>) {
        guard let index = activeIndex else { return }
        var tab = tabs[index]
        tab.expandedNodeIDs = ids
        tabs[index] = tab
    }

    func applyInlineKeyEdit(nodeID: String, newKey: String) {
        guard let index = activeIndex else { return }
        guard let oldNode = Self.findNode(in: tabs[index].treeNodes, id: nodeID), oldNode.key != nil else { return }
        guard let root = tabs[index].rootValue else { return }

        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        pushUndo(at: index)
        guard var tab = tabs[safe: index] else { return }

        do {
            let mutated = try editor.renameKey(root: root, location: oldNode.location, newKey: trimmed)
            applyMutatedRoot(mutated, to: &tab, status: "Renamed key")
            let newSelectionID = renamedLocation(oldNode.location, newKey: trimmed).id
            tab.selectedNodeID = Self.findNode(in: tab.treeNodes, id: newSelectionID) != nil ? newSelectionID : nil
            tabs[index] = tab
        } catch {
            tab.statusText = error.localizedDescription
            tabs[index] = tab
        }
    }

    func applyInlineValueEdit(nodeID: String, newValueText: String) {
        guard let index = activeIndex else { return }
        guard let node = Self.findNode(in: tabs[index].treeNodes, id: nodeID) else { return }
        guard let root = tabs[index].rootValue else { return }
        guard !node.isContainer else { return }

        pushUndo(at: index)
        guard var tab = tabs[safe: index] else { return }

        do {
            let value = try editor.coerceValue(from: newValueText, to: node.type)
            let mutated = try editor.updateValue(root: root, location: node.location, newValue: value)
            applyMutatedRoot(mutated, to: &tab, status: "Updated value")
            tab.selectedNodeID = nodeID
            tabs[index] = tab
        } catch {
            tab.statusText = error.localizedDescription
            tabs[index] = tab
        }
    }

    func selectedNode() -> JsonNode? {
        guard let tab = activeTab, let selectedNodeID = tab.selectedNodeID else { return nil }
        return Self.findNode(in: tab.treeNodes, id: selectedNodeID)
    }

    func expandEmbeddedForSelectedNode() {
        guard let index = activeIndex else { return }
        var tab = tabs[index]
        guard let node = selectedNode(), node.canExpandEmbedded else { return }

        tab.expandedEmbeddedNodeIDs.insert(node.id)
        if let root = tab.rootValue {
            tab.treeNodes = buildTree(for: root, expandedEmbeddedNodeIDs: tab.expandedEmbeddedNodeIDs)
            reconcileExpandedState(for: &tab)
            refreshSearchMatches(for: &tab)
            tab.statusText = "Expanded embedded JSON"
        }
        tabs[index] = tab
    }

    func applyEditOnSelectedNode(newValueText: String, targetType: JsonNodeType, maybeNewKey: String?) {
        guard let index = activeIndex else { return }
        guard let node = selectedNode() else { return }

        pushUndo(at: index)
        guard var tab = tabs[safe: index], let root = tab.rootValue else { return }

        do {
            var mutated = root
            if let maybeNewKey, node.key != nil, !maybeNewKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                mutated = try editor.renameKey(root: mutated, location: node.location, newKey: maybeNewKey)
            }

            let value = try editor.coerceValue(from: newValueText, to: targetType)
            mutated = try editor.updateValue(root: mutated, location: node.location, newValue: value)

            applyMutatedRoot(mutated, to: &tab, status: "Updated node")
            tabs[index] = tab
        } catch {
            tab.statusText = error.localizedDescription
            tabs[index] = tab
        }
    }

    func addSiblingForSelectedNode() {
        applyTreeMutation(status: "Added sibling") { root, node in
            try self.editor.addSibling(root: root, location: node.location)
        }
    }

    func addChildForSelectedNode() {
        applyTreeMutation(status: "Added child") { root, node in
            try self.editor.addChild(root: root, location: node.location)
        }
    }

    func deleteSelectedNode() {
        applyTreeMutation(status: "Deleted node") { root, node in
            try self.editor.deleteNode(root: root, location: node.location)
        }
    }

    func undo() {
        guard let index = activeIndex else { return }
        var tab = tabs[index]
        guard let snapshot = tab.undoStack.popLast() else { return }

        let current = tab.makeSnapshot()
        tab.redoStack.append(current)
        tab.apply(snapshot: snapshot)
        rebuildTreeAndText(for: &tab)
        tab.statusText = "Undo"
        tabs[index] = tab
    }

    func redo() {
        guard let index = activeIndex else { return }
        var tab = tabs[index]
        guard let snapshot = tab.redoStack.popLast() else { return }

        let current = tab.makeSnapshot()
        tab.undoStack.append(current)
        tab.apply(snapshot: snapshot)
        rebuildTreeAndText(for: &tab)
        tab.statusText = "Redo"
        tabs[index] = tab
    }

    private func applyTreeMutation(status: String, mutation: (JsonValue, JsonNode) throws -> JsonValue) {
        guard let index = activeIndex else { return }
        guard let node = selectedNode() else { return }

        pushUndo(at: index)
        guard var tab = tabs[safe: index], let root = tab.rootValue else { return }

        do {
            let mutated = try mutation(root, node)
            applyMutatedRoot(mutated, to: &tab, status: status)
            tabs[index] = tab
        } catch {
            tab.statusText = error.localizedDescription
            tabs[index] = tab
        }
    }

    private func applyMutatedRoot(_ root: JsonValue, to tab: inout TabSession, status: String) {
        tab.rootValue = root
        tab.parseError = nil
        tab.isDirty = true
        tab.isTextMinified = false
        tab.statusText = status
        tab.treeNodes = buildTree(for: root, expandedEmbeddedNodeIDs: tab.expandedEmbeddedNodeIDs)
        reconcileExpandedState(for: &tab)

        do {
            tab.rawText = try parser.stringify(value: root, pretty: true)
        } catch {
            tab.statusText = "Failed to serialize JSON"
        }
        refreshSearchMatches(for: &tab)
    }

    private var activeIndex: Int? {
        guard let activeTabID else { return nil }
        return tabs.firstIndex(where: { $0.id == activeTabID })
    }

    private var shouldReuseCurrentEmptyTab: Bool {
        guard let tab = activeTab else { return false }
        return tab.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && tab.rootValue == nil
    }

    private func nextClipboardTabTitle() -> String {
        let prefix = "Clipboard_"
        let highestIndex = tabs.compactMap { tab -> Int? in
            guard tab.title.hasPrefix(prefix) else { return nil }
            let suffix = String(tab.title.dropFirst(prefix.count))
            return Int(suffix)
        }.max() ?? 0
        return "\(prefix)\(highestIndex + 1)"
    }

    @discardableResult
    private func createTabForIncomingJSON(preferredTitle: String) -> UUID {
        let tab = TabSession.empty(named: preferredTitle)
        tabs.append(tab)
        return tab.id
    }

    private func parseAndAttach(text: String, tabID: UUID?, shouldSelect: Bool) {
        guard let tabID, let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }

        var tab = tabs[index]
        tab.rawText = text
        tab.isDirty = false
        tab.isTextMinified = false
        tab.searchQuery = ""
        tab.searchMatchedNodeIDs = []
        tab.textSearchMatchRanges = []
        tab.searchCurrentMatchIndex = 0
        tab.selectedNodeID = nil

        switch parser.parse(text: text) {
        case .success(let root):
            tab.rootValue = root
            tab.parseError = nil
            tab.mode = .tree
            tab.title = titleFrom(root: root, fallback: tab.title)
            if let formatted = try? parser.stringify(value: root, pretty: true) {
                tab.rawText = formatted
            }
            tab.treeNodes = buildTree(for: root, expandedEmbeddedNodeIDs: tab.expandedEmbeddedNodeIDs)
            tab.expandedNodeIDs = defaultExpandedContainerNodeIDs(in: tab.treeNodes)
            tab.statusText = "Parsed JSON"
        case .failure(let error):
            tab.rootValue = nil
            tab.parseError = error
            tab.treeNodes = []
            tab.expandedNodeIDs = []
            tab.statusText = error.message
        }

        tabs[index] = tab

        if shouldSelect {
            activeTabID = tabID
        }
    }

    private func titleFrom(root: JsonValue, fallback: String) -> String {
        guard case .object(let items) = root else {
            return fallback
        }

        let preferred = ["response", "payload", "order", "data", "result"]
        for key in preferred where items.contains(where: { $0.0 == key }) {
            return key
        }
        if let first = items.first?.0 {
            return first
        }
        return fallback
    }

    private func setStatusForActive(_ message: String) {
        guard let index = activeIndex else { return }
        var tab = tabs[index]
        tab.statusText = message
        tabs[index] = tab
    }

    private func pushUndo(at index: Int) {
        var tab = tabs[index]
        tab.undoStack.append(tab.makeSnapshot())
        if tab.undoStack.count > 100 {
            tab.undoStack.removeFirst(tab.undoStack.count - 100)
        }
        tab.redoStack.removeAll()
        tabs[index] = tab
    }

    private func rebuildTreeAndText(for tab: inout TabSession) {
        if let root = tab.rootValue {
            tab.treeNodes = buildTree(for: root, expandedEmbeddedNodeIDs: tab.expandedEmbeddedNodeIDs)
            reconcileExpandedState(for: &tab)
            if let text = try? parser.stringify(value: root, pretty: true) {
                tab.rawText = text
                tab.isTextMinified = false
            }
            refreshSearchMatches(for: &tab)
        } else {
            tab.treeNodes = []
            tab.expandedNodeIDs = []
            tab.searchMatchedNodeIDs = []
            tab.textSearchMatchRanges = []
            tab.searchCurrentMatchIndex = 0
        }
    }

    private func syncTextToTreeForModeSwitch(_ tab: inout TabSession) -> Bool {
        let trimmed = tab.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            tab.rootValue = nil
            tab.parseError = nil
            tab.treeNodes = []
            tab.expandedNodeIDs = []
            tab.selectedNodeID = nil
            tab.statusText = "Ready"
            return true
        }

        switch parser.parse(text: tab.rawText) {
        case .success(let root):
            tab.rootValue = root
            tab.parseError = nil
            tab.treeNodes = buildTree(for: root, expandedEmbeddedNodeIDs: tab.expandedEmbeddedNodeIDs)
            reconcileExpandedState(for: &tab)
            tab.statusText = "Synced text to tree"
            tab.isDirty = true
            return true
        case .failure(let error):
            tab.parseError = error
            tab.statusText = "Cannot switch to tree: \(error.message)"
            return false
        }
    }

    private func buildTree(for root: JsonValue, expandedEmbeddedNodeIDs: Set<String>) -> [JsonNode] {
        treeBuilder.buildTree(
            from: root,
            maxEmbeddedDepth: settings.embeddedJSONMaxDepth,
            expandedEmbeddedNodeIDs: expandedEmbeddedNodeIDs
        )
    }

    private func defaultExpandedContainerNodeIDs(in nodes: [JsonNode]) -> Set<String> {
        var expanded: Set<String> = []
        func walk(_ node: JsonNode) {
            if node.isContainer, node.isExpandedByDefault {
                expanded.insert(node.id)
            }
            for child in node.children {
                walk(child)
            }
        }
        for node in nodes {
            walk(node)
        }
        return expanded
    }

    private func allContainerNodeIDs(in nodes: [JsonNode]) -> Set<String> {
        var ids: Set<String> = []
        func walk(_ node: JsonNode) {
            if node.isContainer {
                ids.insert(node.id)
            }
            for child in node.children {
                walk(child)
            }
        }
        for node in nodes {
            walk(node)
        }
        return ids
    }

    private func expandableEmbeddedNodeIDs(in nodes: [JsonNode]) -> Set<String> {
        var ids: Set<String> = []
        func walk(_ node: JsonNode) {
            if node.canExpandEmbedded {
                ids.insert(node.id)
            }
            for child in node.children {
                walk(child)
            }
        }
        for node in nodes {
            walk(node)
        }
        return ids
    }

    private func allNodeIDs(in nodes: [JsonNode]) -> Set<String> {
        var ids: Set<String> = []
        func walk(_ node: JsonNode) {
            ids.insert(node.id)
            for child in node.children {
                walk(child)
            }
        }
        for node in nodes {
            walk(node)
        }
        return ids
    }

    private func reconcileExpandedState(for tab: inout TabSession) {
        let validIDs = allNodeIDs(in: tab.treeNodes)
        tab.expandedNodeIDs = tab.expandedNodeIDs.intersection(validIDs)
        if tab.expandedNodeIDs.isEmpty {
            tab.expandedNodeIDs = defaultExpandedContainerNodeIDs(in: tab.treeNodes)
        }
    }

    private func collectSearchMatches(in nodes: [JsonNode], loweredQuery: String) -> [String] {
        var ids: [String] = []
        func walk(_ node: JsonNode) {
            if nodeMatchesQuery(node, loweredQuery: loweredQuery) {
                ids.append(node.id)
            }
            for child in node.children {
                walk(child)
            }
        }
        for node in nodes {
            walk(node)
        }
        return ids
    }

    private func nodeMatchesQuery(_ node: JsonNode, loweredQuery: String) -> Bool {
        if let key = node.key?.lowercased(), key.contains(loweredQuery) {
            return true
        }
        if node.location.displayPath.lowercased().contains(loweredQuery) {
            return true
        }
        if node.displayValue.lowercased().contains(loweredQuery) {
            return true
        }
        return false
    }

    private func refreshSearchMatches(for tab: inout TabSession) {
        let trimmed = tab.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            tab.searchMatchedNodeIDs = []
            tab.textSearchMatchRanges = []
            tab.searchCurrentMatchIndex = 0
            return
        }

        tab.searchMatchedNodeIDs = collectSearchMatches(in: tab.treeNodes, loweredQuery: trimmed.lowercased())
        tab.textSearchMatchRanges = collectTextSearchMatches(in: tab.rawText, query: trimmed)
        let activeMatchCount = tab.mode == .text ? tab.textSearchMatchRanges.count : tab.searchMatchedNodeIDs.count
        if activeMatchCount == 0 {
            tab.searchCurrentMatchIndex = 0
            return
        }
        tab.searchCurrentMatchIndex = min(tab.searchCurrentMatchIndex, activeMatchCount - 1)
    }

    private func revealSearchMatch(in tab: inout TabSession, at index: Int) {
        guard tab.searchMatchedNodeIDs.indices.contains(index) else { return }
        tab.searchCurrentMatchIndex = index
        let matchID = tab.searchMatchedNodeIDs[index]
        if let ancestors = ancestorMap(for: tab.treeNodes)[matchID] {
            tab.expandedNodeIDs.formUnion(ancestors)
        }
        tab.selectedNodeID = matchID
        tab.statusText = "Match \(index + 1) / \(tab.searchMatchedNodeIDs.count)"
    }

    private func renamedLocation(_ location: JsonNodeLocation, newKey: String) -> JsonNodeLocation {
        if !location.embeddedPath.isEmpty {
            var embedded = location.embeddedPath
            if let last = embedded.last, case .key = last {
                embedded[embedded.count - 1] = .key(newKey)
            }
            return JsonNodeLocation(basePath: location.basePath, embeddedPath: embedded)
        }

        var base = location.basePath
        if let last = base.last, case .key = last {
            base[base.count - 1] = .key(newKey)
        }
        return JsonNodeLocation(basePath: base, embeddedPath: location.embeddedPath)
    }

    private func ancestorMap(for nodes: [JsonNode]) -> [String: [String]] {
        var map: [String: [String]] = [:]
        func walk(_ node: JsonNode, ancestors: [String]) {
            map[node.id] = ancestors
            let nextAncestors = node.isContainer ? ancestors + [node.id] : ancestors
            for child in node.children {
                walk(child, ancestors: nextAncestors)
            }
        }
        for node in nodes {
            walk(node, ancestors: [])
        }
        return map
    }

    private static func findNode(in nodes: [JsonNode], id: String) -> JsonNode? {
        for node in nodes {
            if node.id == id { return node }
            if let child = findNode(in: node.children, id: id) {
                return child
            }
        }
        return nil
    }

    private func collectTextSearchMatches(in text: String, query: String) -> [NSRange] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let nsText = text as NSString
        var result: [NSRange] = []
        var searchRange = NSRange(location: 0, length: nsText.length)

        while searchRange.length > 0 {
            let found = nsText.range(
                of: trimmed,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                range: searchRange
            )
            guard found.location != NSNotFound else { break }
            result.append(found)

            let nextLocation = found.location + max(found.length, 1)
            if nextLocation >= nsText.length {
                break
            }
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }

        return result
    }

    private func clearSearchStateForActiveTab(clearTreeSelection: Bool) {
        guard let index = activeIndex else { return }
        var tab = tabs[index]
        tab.searchQuery = ""
        tab.searchMatchedNodeIDs = []
        tab.textSearchMatchRanges = []
        tab.searchCurrentMatchIndex = 0
        if clearTreeSelection, tab.mode == .tree {
            tab.selectedNodeID = nil
        }
        tab.statusText = "Search cleared"
        tabs[index] = tab
    }

}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
