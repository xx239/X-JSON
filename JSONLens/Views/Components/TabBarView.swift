import SwiftUI

struct TabBarView: View {
    let tabs: [TabSession]
    let activeTabID: UUID?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onNew: () -> Void
    let onRename: (UUID, String) -> Void
    let allowDoubleClickRename: Bool

    @State private var editingTabID: UUID?
    @State private var renameDraft: String = ""
    @FocusState private var focusedRenameTabID: UUID?

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        tabChip(tab)
                    }
                }
            }

            Divider().opacity(0.45)

            Button(action: onNew) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("New Tab")
        }
        .frame(height: 34)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
        .onChange(of: focusedRenameTabID) { newValue in
            guard let editingTabID else { return }
            if newValue != editingTabID {
                DispatchQueue.main.async {
                    finishRename(tabID: editingTabID)
                }
            }
        }
    }

    @ViewBuilder
    private func tabChip(_ tab: TabSession) -> some View {
        let isActive = tab.id == activeTabID

        HStack(spacing: 6) {
            if editingTabID == tab.id {
                TextField("Tab Name", text: $renameDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .focused($focusedRenameTabID, equals: tab.id)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onSubmit {
                        finishRename(tabID: tab.id)
                    }
            } else {
                Button {
                    onSelect(tab.id)
                } label: {
                    Text(tab.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        guard allowDoubleClickRename else { return }
                        onSelect(tab.id)
                        editingTabID = tab.id
                        renameDraft = tab.title
                        DispatchQueue.main.async {
                            focusedRenameTabID = tab.id
                        }
                    }
                )
            }

            if tab.isDirty {
                Circle()
                    .fill(Color.orange.opacity(0.92))
                    .frame(width: 6, height: 6)
            }

            Button {
                onClose(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isActive ? 0.8 : 0.5)
        }
        .padding(.horizontal, 10)
        .frame(width: 170, height: 33, alignment: .center)
        .background(
            ZStack(alignment: .top) {
                if isActive {
                    Color.white
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.9))
                        .frame(height: 2)
                } else {
                    Color.white
                }
            }
        )
        .overlay(alignment: .trailing) {
            Divider().opacity(0.45)
        }
    }

    private func finishRename(tabID: UUID) {
        onRename(tabID, renameDraft)
        editingTabID = nil
        focusedRenameTabID = nil
    }
}
