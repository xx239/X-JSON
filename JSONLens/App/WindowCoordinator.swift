import AppKit
import Foundation

final class WindowCoordinator: ObservableObject {
    func showSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func activateMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.isVisible && $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
    }

    func applyWindowBehavior(settings: AppSettings) {
        let level: NSWindow.Level = settings.alwaysOnTop ? .floating : .normal
        for window in NSApp.windows where window.canBecomeMain {
            window.level = level
            window.isOpaque = false
            window.backgroundColor = NSColor.white.withAlphaComponent(settings.backgroundOpacity)
        }
    }
}
