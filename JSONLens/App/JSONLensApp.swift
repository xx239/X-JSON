import SwiftUI

@main
struct JSONLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("X-JSON") {
            MainWindowView()
                .environmentObject(appState)
                .frame(minWidth: 980, minHeight: 620)
        }
        .commands {
            AppCommands(appState: appState)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 560, height: 440)
        }
    }
}

struct AppCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandMenu("X-JSON") {
            Button("Paste and Parse") {
                appState.tabManager.pasteFromCommandShortcut()
            }
            .keyboardShortcut("v", modifiers: .command)

            Button("New Tab") {
                appState.tabManager.newTab(select: true)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Close Current Tab") {
                appState.tabManager.closeActiveTab()
            }
            .keyboardShortcut("w", modifiers: .command)

            Divider()

            Button("Tree View") {
                appState.tabManager.setMode(.tree)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Text View") {
                appState.tabManager.setMode(.text)
            }
            .keyboardShortcut("2", modifiers: .command)

            Divider()

            Button("Find") {
                if appState.tabManager.isSearchBarVisible {
                    appState.tabManager.hideSearchBar()
                } else {
                    appState.tabManager.showSearchBar()
                }
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Find Next") {
                appState.tabManager.findNextSearchMatch()
            }
            .keyboardShortcut("g", modifiers: .command)

            Divider()

            Button("Format JSON") {
                appState.tabManager.formatActiveJSON()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button("Minify JSON") {
                appState.tabManager.performMinifyAction()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Divider()

            Button("Undo") {
                appState.tabManager.undo()
            }
            .keyboardShortcut("z", modifiers: .command)

            Button("Redo") {
                appState.tabManager.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
    }
}
