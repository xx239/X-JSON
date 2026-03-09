import AppKit
import Foundation

struct ClipboardJSONEvent {
    let text: String
    let wasAppActive: Bool
}

final class ClipboardMonitor {
    var onJSONDetected: ((ClipboardJSONEvent) -> Void)?

    private let parser: JsonParseService
    private let queue = DispatchQueue(label: "xjson.clipboard.monitor", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastFingerprint: Int?

    private var isEnabled: Bool = true
    private var autoParse: Bool = true
    private var maxSizeBytes: Int = 512 * 1024

    init(parser: JsonParseService) {
        self.parser = parser
    }

    deinit {
        stop()
    }

    func updateConfiguration(settings: AppSettings) {
        isEnabled = settings.enableClipboardMonitoring
        autoParse = settings.autoParseClipboardJSON
        maxSizeBytes = max(1, settings.maxClipboardSizeKB) * 1024

        if isEnabled {
            startIfNeeded()
        } else {
            stop()
        }
    }

    func startIfNeeded() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .seconds(1), repeating: .milliseconds(700), leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in
            self?.pollPasteboard()
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func pollPasteboard() {
        guard isEnabled, autoParse else { return }

        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard let text = pasteboard.string(forType: .string) else { return }
        let fingerprint = text.hashValue
        guard fingerprint != lastFingerprint else { return }
        lastFingerprint = fingerprint

        guard text.lengthOfBytes(using: .utf8) <= maxSizeBytes else { return }

        switch parser.parse(text: text) {
        case .success:
            DispatchQueue.main.async {
                let event = ClipboardJSONEvent(text: text, wasAppActive: NSApp.isActive)
                self.onJSONDetected?(event)
            }
        case .failure:
            break
        }
    }
}
