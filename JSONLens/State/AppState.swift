import AppKit
import Foundation
import SwiftUI

struct ClipboardToast: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            settingsService.save(settings)
            let latest = settings
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.clipboardMonitor.updateConfiguration(settings: latest)
                self.tabManager.updateSettings(latest)
            }
        }
    }

    @Published var toast: ClipboardToast?

    let windowCoordinator = WindowCoordinator()
    let parser: JsonParseService
    let detector: EmbeddedJsonDetector
    let treeBuilder: JsonTreeBuilder
    let editor: JsonEditService
    let settingsService: SettingsService
    let clipboardMonitor: ClipboardMonitor
    let tabManager: TabSessionManager

    init() {
        let parser = JsonParseService()
        let settingsService = SettingsService()
        let loadedSettings = settingsService.load()

        self.parser = parser
        self.detector = EmbeddedJsonDetector(parser: parser)
        self.treeBuilder = JsonTreeBuilder(detector: detector)
        self.editor = JsonEditService(parser: parser)
        self.settingsService = settingsService
        self.clipboardMonitor = ClipboardMonitor(parser: parser)
        self.settings = loadedSettings
        self.tabManager = TabSessionManager(
            parser: parser,
            treeBuilder: treeBuilder,
            editor: editor,
            settings: loadedSettings
        )

        self.tabManager.selectTab(self.tabManager.tabs[0].id)
        installCallbacks()
        tabManager.updateSettings(settings)
        clipboardMonitor.updateConfiguration(settings: settings)
    }

    func pasteAndParse() {
        tabManager.pasteAndParseFromPasteboard()
    }

    func showSettingsWindowLegacy() {
        windowCoordinator.showSettings()
    }

    func consumeToast() {
        toast = nil
    }

    private func installCallbacks() {
        clipboardMonitor.onJSONDetected = { [weak self] event in
            guard let self else { return }
            self.tabManager.handleClipboardJSON(event.text, isForeground: event.wasAppActive)
            if !event.wasAppActive {
                let subtitle = self.settings.openDetectedJSONInNewTab
                    ? "A new tab has been prepared"
                    : "Current tab has been updated"
                self.toast = ClipboardToast(
                    title: "New JSON detected in clipboard",
                    subtitle: subtitle
                )
            }
        }
    }
}
