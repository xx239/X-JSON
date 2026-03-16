import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Keep contrast stable because the app uses a white surface design.
        NSApp.appearance = NSAppearance(named: .aqua)
        applyAppIcon()
    }

    private func applyAppIcon() {
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("AppIcon.icns"),
            Bundle.main.resourceURL?.appendingPathComponent("AppIcon-1024.png"),
            Bundle.main.bundleURL.appendingPathComponent("XJSON_XJSON.bundle/Resources/AppIcon.icns"),
            Bundle.main.bundleURL.appendingPathComponent("XJSON_XJSON.bundle/Resources/AppIcon-1024.png"),
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("XJSON_XJSON.bundle/Resources/AppIcon.icns"),
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("XJSON_XJSON.bundle/Resources/AppIcon-1024.png")
        ]

        for case let url? in candidates {
            if let image = NSImage(contentsOf: url) {
                NSApp.applicationIconImage = image
                return
            }
        }
    }
}
