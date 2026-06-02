import Foundation

/// 앱 표시 언어. `system` 은 기기 언어를 따른다(오버라이드 없음).
public enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case ko
    case en
    case ja

    /// 스위즐에 넘길 `.lproj` 코드. system 은 nil(오버라이드 없음).
    public var bundleCode: String? { self == .system ? nil : rawValue }

    /// 날짜/숫자 형식용 로케일.
    public var locale: Locale {
        switch self {
        case .system: return Locale.autoupdatingCurrent
        case .ko:     return Locale(identifier: "ko")
        case .en:     return Locale(identifier: "en")
        case .ja:     return Locale(identifier: "ja")
        }
    }

    /// 설정 화면 표시명. system 만 현지화, 나머지는 endonym 고정.
    public var displayName: String {
        switch self {
        case .system: return String(localized: "시스템 설정")
        case .ko:     return "한국어"
        case .en:     return "English"
        case .ja:     return "日本語"
        }
    }
}
