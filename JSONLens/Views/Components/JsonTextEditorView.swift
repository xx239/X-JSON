import AppKit
import SwiftUI

struct JsonTextEditorView: View {
    @Binding var text: String
    let parseError: JsonParseError?
    let searchQuery: String
    let searchMatchRanges: [NSRange]
    let selectedSearchMatchIndex: Int
    let fontFamily: AppFontFamily
    let fontSize: CGFloat
    let surfaceOpacity: Double
    let onSyncToTree: () -> Void

    private var lineNumbers: String {
        semanticLineLabels(in: text).joined(separator: "\n")
    }

    private var visibleLineCount: Int {
        semanticLineLabels(in: text).count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(lineNumbers)
                        .font(AppTypography.monoFont(family: fontFamily, size: fontSize))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 10)
                        .padding(.horizontal, 8)
                }
                .frame(width: 52)
                .background(Color.white.opacity(surfaceOpacity))

                JsonCodeEditorTextView(
                    text: $text,
                    searchQuery: searchQuery,
                    searchMatchRanges: searchMatchRanges,
                    selectedSearchMatchIndex: selectedSearchMatchIndex,
                    fontFamily: fontFamily,
                    fontSize: fontSize
                )
                .background(Color.clear)
            }
            .background(Color.white.opacity(surfaceOpacity))

            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Button("Sync to Tree") {
                        onSyncToTree()
                    }
                    .buttonStyle(.plain)
                    .font(AppTypography.monoFont(family: fontFamily, size: fontSize, weight: .semibold))

                    Spacer()

                    Text("Lines: \(visibleLineCount)")
                        .font(AppTypography.monoFont(family: fontFamily, size: max(10, fontSize - 1)))
                        .foregroundStyle(.secondary)
                }

                if let parseError {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(parseError.message)
                            .font(AppTypography.monoFont(family: fontFamily, size: max(10, fontSize - 1), weight: .semibold))
                            .foregroundStyle(.red)
                            .textSelection(.enabled)

                        if let context = parseError.contextDisplay {
                            Text(context)
                                .font(AppTypography.monoFont(family: fontFamily, size: max(10, fontSize - 1)))
                                .foregroundStyle(.red.opacity(0.9))
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(surfaceOpacity))
        }
    }

    private func semanticLineLabels(in source: String) -> [String] {
        if source.isEmpty {
            return ["1"]
        }

        var labels: [String] = []
        var lineNumber = 1
        var inString = false
        var escaped = false

        labels.append("1")

        for char in source {
            if char == "\n" {
                lineNumber += 1
                labels.append(inString ? "" : "\(lineNumber)")
                escaped = false
                continue
            }

            if inString {
                if escaped {
                    escaped = false
                    continue
                }
                if char == "\\" {
                    escaped = true
                    continue
                }
                if char == "\"" {
                    inString = false
                }
            } else if char == "\"" {
                inString = true
            }
        }

        return labels
    }
}

private struct JsonCodeEditorTextView: NSViewRepresentable {
    @Binding var text: String
    let searchQuery: String
    let searchMatchRanges: [NSRange]
    let selectedSearchMatchIndex: Int
    let fontFamily: AppFontFamily
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = AppTypography.nsMonoFont(family: fontFamily, size: fontSize)
        textView.textColor = .labelColor
        textView.backgroundColor = .white
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 2, height: 6)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = false
        }

        scrollView.documentView = textView
        applySearchHighlights(on: textView, shouldScrollToCurrentMatch: true)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        textView.font = AppTypography.nsMonoFont(family: fontFamily, size: fontSize)

        if textView.string != text {
            context.coordinator.isProgrammaticUpdate = true
            let selectedRange = textView.selectedRange()
            textView.string = text
            let maxLocation = (text as NSString).length
            let clampedLocation = min(selectedRange.location, maxLocation)
            textView.setSelectedRange(NSRange(location: clampedLocation, length: 0))
            context.coordinator.isProgrammaticUpdate = false
        }

        let shouldScroll = context.coordinator.lastSearchQuery != searchQuery
            || context.coordinator.lastSelectedMatchIndex != selectedSearchMatchIndex
        applySearchHighlights(on: textView, shouldScrollToCurrentMatch: shouldScroll)
        context.coordinator.lastSearchQuery = searchQuery
        context.coordinator.lastSelectedMatchIndex = selectedSearchMatchIndex
    }

    private func applySearchHighlights(
        on textView: NSTextView,
        shouldScrollToCurrentMatch: Bool
    ) {
        guard let textStorage = textView.textStorage else { return }
        let fullLength = (textView.string as NSString).length
        let fullRange = NSRange(location: 0, length: fullLength)

        textStorage.beginEditing()
        textStorage.removeAttribute(.backgroundColor, range: fullRange)

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            for (index, range) in searchMatchRanges.enumerated() {
                guard range.location != NSNotFound, NSMaxRange(range) <= fullLength else { continue }
                let color = index == selectedSearchMatchIndex
                    ? NSColor.systemOrange.withAlphaComponent(0.35)
                    : NSColor.systemYellow.withAlphaComponent(0.22)
                textStorage.addAttribute(.backgroundColor, value: color, range: range)
            }
        }
        textStorage.endEditing()

        guard shouldScrollToCurrentMatch else { return }
        guard searchMatchRanges.indices.contains(selectedSearchMatchIndex) else { return }
        let currentRange = searchMatchRanges[selectedSearchMatchIndex]
        guard currentRange.location != NSNotFound, NSMaxRange(currentRange) <= fullLength else { return }
        textView.scrollRangeToVisible(currentRange)
        textView.showFindIndicator(for: currentRange)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JsonCodeEditorTextView
        var isProgrammaticUpdate: Bool = false
        var lastSearchQuery: String = ""
        var lastSelectedMatchIndex: Int = -1

        init(parent: JsonCodeEditorTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate else { return }
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
