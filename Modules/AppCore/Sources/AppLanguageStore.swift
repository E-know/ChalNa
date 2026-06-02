import Foundation
import Observation

/// 앱 표시 언어의 런타임 단일 출처. UserDefaults 에 영속하고, 변경 시
/// 스위즐(`Bundle.setLanguage`)을 갱신한다. RootView 가 환경으로 주입.
@Observable
@MainActor
public final class AppLanguageStore {
    public static let storageKey = "appLanguage"

    public private(set) var language: AppLanguage

    public init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        self.language = raw.flatMap(AppLanguage.init(rawValue:)) ?? .system
        Bundle.setLanguage(language.bundleCode)
    }

    public func set(_ newValue: AppLanguage) {
        guard newValue != language else { return }
        language = newValue
        UserDefaults.standard.set(newValue.rawValue, forKey: Self.storageKey)
        Bundle.setLanguage(newValue.bundleCode)
    }

    /// 환경 `\.locale` 로 주입 → 날짜/숫자 형식 + 라이브 재렌더 트리거.
    public var locale: Locale { language.locale }

    /// 화면에 실제로 그려지는 UI 언어가 한국어인지.
    /// `.ko/.en/.ja` 직접 선택은 그대로 판정하고, `.system` 은 기기 선호 언어를
    /// 앱 지원 언어(ko/en/ja)에 매칭한 결과의 첫 항목으로 해석한다.
    public var isKoreanUI: Bool {
        if let code = language.bundleCode { return code == "ko" }
        let resolved = Bundle.preferredLocalizations(
            from: ["ko", "en", "ja"],
            forPreferences: Locale.preferredLanguages
        ).first
        return resolved == "ko"
    }

    /// 첫 페인트 전 ChalNaApp.init 에서 호출(인스턴스 없이 스위즐만 설치).
    public nonisolated static func applyStoredLanguageAtLaunch() {
        let raw = UserDefaults.standard.string(forKey: storageKey)
        let lang = raw.flatMap(AppLanguage.init(rawValue:)) ?? .system
        Bundle.setLanguage(lang.bundleCode)
    }
}
