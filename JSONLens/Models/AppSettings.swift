import Foundation

enum AppAppearanceTheme: String, Codable, CaseIterable, Equatable {
    case plumGreen
    case oceanAmber
    case slateCoral

    var displayName: String {
        switch self {
        case .plumGreen:
            return "Plum + Green"
        case .oceanAmber:
            return "Ocean + Amber"
        case .slateCoral:
            return "Slate + Coral"
        }
    }

    var treeKeyHexColor: String {
        switch self {
        case .plumGreen:
            return "#80217D"
        case .oceanAmber:
            return "#1f4ba5"
        case .slateCoral:
            return "#4b5563"
        }
    }

    var treeStringHexColor: String {
        switch self {
        case .plumGreen:
            return "#3AB54A"
        case .oceanAmber:
            return "#a16207"
        case .slateCoral:
            return "#b4534d"
        }
    }

    var treeBooleanHexColor: String {
        switch self {
        case .plumGreen:
            return "#F98280"
        case .oceanAmber:
            return "#C2410C"
        case .slateCoral:
            return "#EF4444"
        }
    }

    var treeNumberHexColor: String {
        switch self {
        case .plumGreen:
            return "#25AAE2"
        case .oceanAmber:
            return "#0369A1"
        case .slateCoral:
            return "#0EA5E9"
        }
    }

    var treeNullHexColor: String {
        switch self {
        case .plumGreen:
            return "#F1592A"
        case .oceanAmber:
            return "#BE123C"
        case .slateCoral:
            return "#F97316"
        }
    }
}

enum AppFontFamily: String, Codable, CaseIterable, Equatable {
    case systemMonospaced
    case systemMonospacedSemibold
    case systemMonospacedBold
    case menlo
    case menloBold
    case monaco
    case courierNew
    case courierNewBold

    var displayName: String {
        switch self {
        case .systemMonospaced:
            return "System Monospaced"
        case .systemMonospacedSemibold:
            return "System Monospaced Semibold"
        case .systemMonospacedBold:
            return "System Monospaced Bold"
        case .menlo:
            return "Menlo"
        case .menloBold:
            return "Menlo Bold"
        case .monaco:
            return "Monaco"
        case .courierNew:
            return "Courier New"
        case .courierNewBold:
            return "Courier New Bold"
        }
    }

    var nsFontName: String? {
        switch self {
        case .systemMonospaced:
            return nil
        case .systemMonospacedSemibold:
            return nil
        case .systemMonospacedBold:
            return nil
        case .menlo:
            return "Menlo-Regular"
        case .menloBold:
            return "Menlo-Bold"
        case .monaco:
            return "Monaco"
        case .courierNew:
            return "CourierNewPSMT"
        case .courierNewBold:
            return "CourierNewPS-BoldMT"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var launchWithDefaultWindow: Bool = true
    var appearanceTheme: AppAppearanceTheme = .plumGreen
    var editorFontFamily: AppFontFamily = .systemMonospaced
    var editorFontSize: Int = 12
    var enableClipboardMonitoring: Bool = true
    var autoParseClipboardJSON: Bool = true
    var openDetectedJSONInNewTab: Bool = true
    var maxClipboardSizeKB: Int = 512
    var embeddedJSONMaxDepth: Int = 5
    var doubleClickToEdit: Bool = true
    var confirmBeforeDelete: Bool = false

    private enum CodingKeys: String, CodingKey {
        case launchWithDefaultWindow
        case appearanceTheme
        case editorFontFamily
        case editorFontSize
        case enableClipboardMonitoring
        case autoParseClipboardJSON
        case openDetectedJSONInNewTab
        case maxClipboardSizeKB
        case embeddedJSONMaxDepth
        case doubleClickToEdit
        case confirmBeforeDelete
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchWithDefaultWindow = try container.decodeIfPresent(Bool.self, forKey: .launchWithDefaultWindow) ?? true
        appearanceTheme = try container.decodeIfPresent(AppAppearanceTheme.self, forKey: .appearanceTheme) ?? .plumGreen
        editorFontFamily = try container.decodeIfPresent(AppFontFamily.self, forKey: .editorFontFamily) ?? .systemMonospaced
        editorFontSize = try container.decodeIfPresent(Int.self, forKey: .editorFontSize) ?? 12
        enableClipboardMonitoring = try container.decodeIfPresent(Bool.self, forKey: .enableClipboardMonitoring) ?? true
        autoParseClipboardJSON = try container.decodeIfPresent(Bool.self, forKey: .autoParseClipboardJSON) ?? true
        openDetectedJSONInNewTab = try container.decodeIfPresent(Bool.self, forKey: .openDetectedJSONInNewTab) ?? true
        maxClipboardSizeKB = try container.decodeIfPresent(Int.self, forKey: .maxClipboardSizeKB) ?? 512
        embeddedJSONMaxDepth = try container.decodeIfPresent(Int.self, forKey: .embeddedJSONMaxDepth) ?? 5
        doubleClickToEdit = try container.decodeIfPresent(Bool.self, forKey: .doubleClickToEdit) ?? true
        confirmBeforeDelete = try container.decodeIfPresent(Bool.self, forKey: .confirmBeforeDelete) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(launchWithDefaultWindow, forKey: .launchWithDefaultWindow)
        try container.encode(appearanceTheme, forKey: .appearanceTheme)
        try container.encode(editorFontFamily, forKey: .editorFontFamily)
        try container.encode(editorFontSize, forKey: .editorFontSize)
        try container.encode(enableClipboardMonitoring, forKey: .enableClipboardMonitoring)
        try container.encode(autoParseClipboardJSON, forKey: .autoParseClipboardJSON)
        try container.encode(openDetectedJSONInNewTab, forKey: .openDetectedJSONInNewTab)
        try container.encode(maxClipboardSizeKB, forKey: .maxClipboardSizeKB)
        try container.encode(embeddedJSONMaxDepth, forKey: .embeddedJSONMaxDepth)
        try container.encode(doubleClickToEdit, forKey: .doubleClickToEdit)
        try container.encode(confirmBeforeDelete, forKey: .confirmBeforeDelete)
    }
}
