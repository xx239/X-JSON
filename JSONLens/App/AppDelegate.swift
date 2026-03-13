import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        applyAppIcon()
    }

    private func applyAppIcon() {
        let candidates: [(name: String, ext: String, subdirectory: String?)] = [
            ("AppIcon", "icns", nil),
            ("AppIcon", "icns", "Resources"),
            ("AppIcon-1024", "png", nil),
            ("AppIcon-1024", "png", "Resources")
        ]

        for candidate in candidates {
            if let url = Bundle.module.url(
                forResource: candidate.name,
                withExtension: candidate.ext,
                subdirectory: candidate.subdirectory
            ),
            let image = NSImage(contentsOf: url) {
                NSApp.applicationIconImage = image
                return
            }
        }
    }
}
