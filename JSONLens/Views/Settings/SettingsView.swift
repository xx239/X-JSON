import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch with default window", isOn: binding(\.launchWithDefaultWindow))

                Picker("Appearance theme", selection: binding(\.appearanceTheme)) {
                    ForEach(AppAppearanceTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.menu)

                Picker("Editor font", selection: binding(\.editorFontFamily)) {
                    ForEach(AppFontFamily.allCases, id: \.self) { family in
                        Text(family.displayName).tag(family)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Editor font size")
                    Spacer()
                    Text("\(appState.settings.editorFontSize)")
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                    Stepper("", value: binding(\.editorFontSize), in: 10...22)
                    .labelsHidden()
                }

                HStack {
                    Text("Background opacity")
                    Spacer()
                    Text("\(appState.settings.backgroundOpacityPercent)%")
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                    Slider(value: backgroundOpacityBinding, in: 35...100, step: 5)
                        .frame(width: 180)
                }
            }

            Section("Window") {
                Toggle("Always keep window on top", isOn: binding(\.alwaysOnTop))
                Toggle(
                    "Bring app to front when clipboard JSON is detected",
                    isOn: binding(\.bringToFrontOnClipboardJSON)
                )
            }

            Section("Clipboard") {
                Toggle("Enable clipboard monitoring", isOn: binding(\.enableClipboardMonitoring))
                Toggle("Auto parse clipboard JSON", isOn: binding(\.autoParseClipboardJSON))

                Picker("On clipboard JSON detected", selection: clipboardTabBehaviorBinding) {
                    Text("Create new tab").tag(ClipboardTabBehavior.createNewTab)
                    Text("Overwrite current tab").tag(ClipboardTabBehavior.overwriteCurrentTab)
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Maximum clipboard size")
                    Spacer()
                    Text("\(appState.settings.maxClipboardSizeKB) KB")
                        .foregroundStyle(.secondary)
                        .frame(width: 110, alignment: .trailing)
                    Stepper("", value: binding(\.maxClipboardSizeKB), in: 64...10_240, step: 64)
                    .labelsHidden()
                }
            }

            Section("Tabs") {
                Toggle("Double click to edit", isOn: binding(\.doubleClickToEdit))
            }

            Section("Advanced") {
                HStack {
                    Text("Embedded JSON max depth")
                    Spacer()
                    Text("\(appState.settings.embeddedJSONMaxDepth)")
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                    Stepper("", value: binding(\.embeddedJSONMaxDepth), in: 1...10)
                    .labelsHidden()
                }

                Toggle("Confirm before delete", isOn: binding(\.confirmBeforeDelete))
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { appState.settings[keyPath: keyPath] },
            set: { appState.settings[keyPath: keyPath] = $0 }
        )
    }

    private var clipboardTabBehaviorBinding: Binding<ClipboardTabBehavior> {
        Binding(
            get: { appState.settings.openDetectedJSONInNewTab ? .createNewTab : .overwriteCurrentTab },
            set: { behavior in
                appState.settings.openDetectedJSONInNewTab = (behavior == .createNewTab)
            }
        )
    }

    private var backgroundOpacityBinding: Binding<Double> {
        Binding(
            get: { Double(appState.settings.backgroundOpacityPercent) },
            set: { newValue in
                let rounded = Int((newValue / 5).rounded() * 5)
                appState.settings.backgroundOpacityPercent = min(max(rounded, 35), 100)
            }
        )
    }
}

private enum ClipboardTabBehavior: String, CaseIterable, Hashable {
    case createNewTab
    case overwriteCurrentTab
}
