import Foundation

public enum AppLocalization {
    public static let languagePreferenceKey = "appLanguage"

    private static var selectedLanguageCode: String? {
        let code = UserDefaults.standard.string(forKey: languagePreferenceKey)
        switch code {
        case "ko", "en", "ja": return code
        default: return nil
        }
    }

    /// 문자열 조회에 앱에서 선택한 언어의 번들을 명시한다.
    public static var bundle: Bundle {
        guard let language = selectedLanguageCode,
              let url = Bundle.main.url(forResource: language, withExtension: "lproj"),
              let bundle = Bundle(url: url) else { return .main }
        return bundle
    }

    /// 복수형과 날짜·숫자 표기도 앱에서 선택한 언어를 따른다.
    public static var locale: Locale {
        selectedLanguageCode.map(Locale.init(identifier:)) ?? .autoupdatingCurrent
    }
}
