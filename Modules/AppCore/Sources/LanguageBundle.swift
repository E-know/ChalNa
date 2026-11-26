import Foundation

/// main 번들의 클래스를 이 서브클래스로 바꿔(`object_setClass`) 문자열 조회를
/// 선택 언어의 `.lproj` 로 위임한다. SwiftUI는 환경의 locale을 사용하며,
/// `String(localized:)` 호출에는 `AppLocalization.bundle`을 명시한다.
final class LanguageBundle: Bundle, @unchecked Sendable {
    /// 선택 언어의 `.lproj` 번들. nil 이면 시스템(super) 동작.
    nonisolated(unsafe) static var overrideBundle: Bundle?

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = LanguageBundle.overrideBundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

public extension Bundle {
    /// 앱 언어를 설정한다. `code == nil` 이면 시스템 언어(오버라이드 해제).
    static func setLanguage(_ code: String?) {
        // main 번들의 클래스를 1회 교체(반복 호출 무해).
        object_setClass(Bundle.main, LanguageBundle.self)
        if let code, let path = Bundle.main.path(forResource: code, ofType: "lproj") {
            LanguageBundle.overrideBundle = Bundle(path: path)
        } else {
            LanguageBundle.overrideBundle = nil
        }
    }
}
