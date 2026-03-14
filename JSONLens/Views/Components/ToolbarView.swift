import SwiftUI

struct ToolbarView: View {
    let mode: MainContentMode
    let onPasteParse: () -> Void
    let onMinify: () -> Void
    let minifyTitle: String
    let isInspectorVisible: Bool
    let onToggleInspector: () -> Void
    let onTreeMode: () -> Void
    let onTextMode: () -> Void
    let onOpenSettingsFallback: () -> Void
    let surfaceOpacity: Double

    var body: some View {
        HStack(spacing: 10) {
            actionButton(title: "Paste", icon: "doc.on.clipboard", action: onPasteParse)
            actionButton(title: minifyTitle, icon: "text.justify", action: onMinify)

            Spacer()

            pickerButton(title: "Tree", isActive: mode == .tree, action: onTreeMode)
            pickerButton(title: "Text", isActive: mode == .text, action: onTextMode)
            iconToggleButton(
                icon: isInspectorVisible ? "sidebar.right" : "sidebar.trailing",
                isActive: isInspectorVisible,
                action: onToggleInspector
            )

            Divider()
                .frame(height: 18)

            if #available(macOS 14.0, *) {
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                }
                .help("Settings")
            } else {
                Button(action: onOpenSettingsFallback) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(surfaceOpacity))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.35)
        }
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
            )
        }
        .buttonStyle(.plain)
    }

    private func pickerButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActive ? Color.primary.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func iconToggleButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.primary.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(isActive ? "Hide Inspector" : "Show Inspector")
    }
}
