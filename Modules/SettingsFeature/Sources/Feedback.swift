import Foundation

/// 신고 분류. 텔레그램 메시지 헤더 이모지/한글명 포함.
public enum FeedbackCategory: String, CaseIterable, Sendable, Equatable {
    case bug
    case suggestion
    case other

    public var koreanName: String {
        switch self {
        case .bug:        return "버그"
        case .suggestion: return "제안"
        case .other:      return "기타"
        }
    }

    public var emoji: String {
        switch self {
        case .bug:        return "🐞"
        case .suggestion: return "💡"
        case .other:      return "💬"
        }
    }
}

/// 사용자 신고 1건. 텍스트 + 분류 + 자동 수집한 앱/기기 메타데이터.
public struct FeedbackReport: Equatable, Sendable {
    /// 텔레그램 메시지 제한(4096 UTF-16 코드유닛)을 고려한 본문 UTF-16 예산. 나머지는 헤더/메타 여유분.
    static let maxBodyUTF16 = 3900

    public var text: String
    public var category: FeedbackCategory
    public var appVersion: String
    public var build: String
    public var iosVersion: String
    public var deviceModel: String

    public init(
        text: String,
        category: FeedbackCategory,
        appVersion: String,
        build: String,
        iosVersion: String,
        deviceModel: String
    ) {
        self.text = text
        self.category = category
        self.appVersion = appVersion
        self.build = build
        self.iosVersion = iosVersion
        self.deviceModel = deviceModel
    }

    /// 런타임에서 앱/기기 메타데이터를 수집해 신고 1건을 구성.
    public static func current(text: String, category: FeedbackCategory) -> FeedbackReport {
        let info = Bundle.main.infoDictionary
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let iosVersion = v.patchVersion > 0
            ? "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
            : "\(v.majorVersion).\(v.minorVersion)"
        return FeedbackReport(
            text: text,
            category: category,
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "?",
            build: info?["CFBundleVersion"] as? String ?? "?",
            iosVersion: iosVersion,
            deviceModel: deviceIdentifier()
        )
    }

    /// 텔레그램으로 보낼 plain text. parse_mode 미사용이라 이스케이프 불필요.
    public var telegramMessageText: String {
        let (body, truncated) = Self.clampToUTF16(text, limit: Self.maxBodyUTF16)
        let clamped = truncated ? body + "…" : body
        let separator = "————————————"
        return """
        \(category.emoji) [\(category.koreanName)] ChalNa 신고
        \(separator)
        \(clamped)
        \(separator)
        앱 \(appVersion) (\(build)) · iOS \(iosVersion) · \(deviceModel)
        """
    }

    /// UTF-16 코드유닛 기준 limit 이하가 되도록 grapheme 경계에서 자른다(이모지 분할 방지).
    /// 텔레그램 메시지 길이 제한은 grapheme 가 아니라 UTF-16 코드유닛으로 센다.
    static func clampToUTF16(_ s: String, limit: Int) -> (text: String, truncated: Bool) {
        guard s.utf16.count > limit else { return (s, false) }
        var result = ""
        var count = 0
        for ch in s {
            let n = String(ch).utf16.count
            if count + n > limit { break }
            result.append(ch)
            count += n
        }
        return (result, true)
    }

    /// 기기 모델 식별자(예: iPhone16,1). 시뮬레이터는 SIMULATOR_MODEL_IDENTIFIER 사용.
    private static func deviceIdentifier() -> String {
        if let simModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simModel
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafeBytes(of: &systemInfo.machine) { raw -> String in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
        return machine.isEmpty ? "unknown" : machine
    }
}
