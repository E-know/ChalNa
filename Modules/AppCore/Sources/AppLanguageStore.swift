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

    /// 첫 페인트 전 ChalNaApp.init 에서 호출(인스턴스 없이 스위즐만 설치).
    public nonisolated static func applyStoredLanguageAtLaunch() {
        let raw = UserDefaults.standard.string(forKey: storageKey)
        let lang = raw.flatMap(AppLanguage.init(rawValue:)) ?? .system
        Bundle.setLanguage(lang.bundleCode)
    }
}
