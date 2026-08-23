import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 자동 시각/날짜 라벨의 **로케일 · 문자열 · 폰트 · 실측** 단일 진실 공급원.
/// 기하는 `LabelLayout` 이, 텍스트와 폰트는 여기가 갖는다.
///
/// 영상 합성(`CompositionService`)과 에디터 미리보기(`AutoLabelsOverlay`)가 **둘 다 이걸 쓴다.**
/// 과거엔 로케일 해석·포매터 2개·폰트가 두 모듈에 바이트 단위로 복제돼 있었고 동기화 수단이
/// 주석뿐이었다 — 한쪽만 고치면 미리보기와 출력이 서로 다른 문자열/폭을 갖는데 컴파일도
/// 테스트도 조용했다.
///
/// **왜 DesignSystem 이 아니라 Models 인가**: DesignSystem 은 의존이 없는 최하단 모듈이고
/// `CompositionService` 는 DesignSystem 을 볼 수 없다. 두 렌더 경로가 공유할 수 있는 유일한
/// 자리가 Models 다 (`LabelLayout` 기하가 이미 여기 사는 것과 같은 이유).
public enum LabelText {

    // MARK: - Locale

    /// 앱에서 선택한 표시 언어("appLanguage", 없으면 시스템)에 맞춘 오버레이 로케일.
    /// 언어 스위즐은 `Bundle` 만 바꾸므로 `Locale.current` 는 기기 언어를 반영한다 —
    /// 따라서 앱 선택 언어를 직접 읽어 매핑한다.
    public static func locale() -> Locale {
        switch UserDefaults.standard.string(forKey: "appLanguage") {
        case "ko": return Locale(identifier: "ko")
        case "en": return Locale(identifier: "en")
        case "ja": return Locale(identifier: "ja")
        default:   return Locale.current
        }
    }

    private static func isEnglish(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "en"
    }

    private static func formatter(_ locale: Locale, _ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = .current
        f.dateFormat = format
        return f
    }

    // MARK: - Strings

    /// 시:분. en 은 12시간(`h:mm a`), 그 외(ko·ja)는 24시간(`HH:mm`). 현재 타임존.
    public static func timeString(_ date: Date, locale: Locale = LabelText.locale()) -> String {
        formatter(locale, isEnglish(locale) ? "h:mm a" : "HH:mm").string(from: date)
    }

    /// 날짜. en 은 `MM/dd/yyyy`, 그 외(ko·ja)는 `yyyy/MM/dd`.
    /// 글리프-세이프 숫자 형식이라 로케일별로 순서만 다르다. 현재 타임존.
    public static func dateString(_ date: Date, locale: Locale = LabelText.locale()) -> String {
        formatter(locale, isEnglish(locale) ? "MM/dd/yyyy" : "yyyy/MM/dd").string(from: date)
    }

    // MARK: - Font

    /// 라벨 폰트(SwiftUI) — 미리보기 렌더용. Dynamic Type 비적용.
    /// `uiFont(px:)` 와 **반드시 같은 폰트**여야 WYSIWYG 가 맞는다. 둘이 한 파일에 붙어 있는
    /// 이유가 그것이고, `LabelTextFontParityTests` 가 그 일치를 검사한다.
    public static func font(px: CGFloat) -> Font {
        .system(size: px, weight: weight, design: .default)
    }

    #if canImport(UIKit)
    /// 라벨 폰트(UIKit) — 실측(`measure`)과 합성(`CATextLayer`)용. `font(px:)` 의 짝.
    public static func uiFont(px: CGFloat) -> UIFont {
        .systemFont(ofSize: px, weight: uiWeight)
    }

    /// 두 폰트가 공유하는 굵기(UIKit 쪽). `weight` 와 같은 값이어야 한다.
    public static let uiWeight: UIFont.Weight = .bold
    #endif

    /// 두 폰트가 공유하는 굵기(SwiftUI 쪽). `uiWeight` 와 같은 값이어야 한다.
    public static let weight: Font.Weight = .bold

    // MARK: - Measurement

    /// 라벨 한 줄의 실측 크기(`ceil`). 합성과 미리보기가 같은 규칙을 써야 우측 정렬이 어긋나지 않는다.
    /// - UIKit: `uiFont(px:)` 로 만든 `NSAttributedString.size()`.
    /// - 비-UIKit(테스트 호스트): 실측 불가 → 글자 수 기반 근사치 `px * max(count,5)` × `px * 1.4`.
    public static func measure(_ text: String, px: CGFloat) -> CGSize {
        #if canImport(UIKit)
        let measured = NSAttributedString(string: text, attributes: [.font: uiFont(px: px)]).size()
        return CGSize(width: ceil(measured.width), height: ceil(measured.height))
        #else
        return CGSize(width: px * CGFloat(max(text.count, 5)), height: px * 1.4)
        #endif
    }

    // MARK: - Stamp bounds (테스트용 가드)

    /// 그림자가 라벨 박스 밖으로 번지는 여유(offset 2 + radius 4). `makeOverlayTextLayer` 의 값과 짝.
    public static let shadowSlack: CGFloat = 6

    /// 시각·날짜 스탬프가 실제로 덮는 영역(**top-left 원점**, 그림자 여유 포함).
    ///
    /// 픽셀 테스트가 "내 샘플 지점이 자동 라벨을 피하는가"를 **손계산 주석 대신** 이걸로 검증한다.
    /// `paddingFraction`/폰트 분수를 바꾸면 이 박스가 따라 움직이므로, 샘플 지점이 라벨에
    /// 걸리는 순간 컴포지터가 아니라 라벨 기하를 가리키며 실패한다.
    public static func stampRect(
        renderSize: CGSize,
        capturedAt: Date,
        locale: Locale = LabelText.locale()
    ) -> CGRect {
        let minDim = min(renderSize.width, renderSize.height)
        let timePx = minDim * LabelLayout.timeFontFraction
        let datePx = minDim * LabelLayout.dateFontFraction
        let gap = minDim * LabelLayout.stackGapFraction
        let padding = CGSize(width: renderSize.width * LabelLayout.paddingFraction,
                             height: renderSize.height * LabelLayout.paddingFraction)

        let timeSize = measure(timeString(capturedAt, locale: locale), px: timePx)
        let dateSize = measure(dateString(capturedAt, locale: locale), px: datePx)
        let origins = LabelLayout.stackedOrigins(
            timeSize: timeSize, dateSize: dateSize,
            gap: gap, renderSize: renderSize, padding: padding
        )

        // y-up 좌하단 origin 2개 → top-left 원점 합집합 박스.
        let minX = min(origins.time.x, origins.date.x)
        let maxX = max(origins.time.x + timeSize.width, origins.date.x + dateSize.width)
        let topYUp = max(origins.time.y + timeSize.height, origins.date.y + dateSize.height)
        let bottomYUp = min(origins.time.y, origins.date.y)

        return CGRect(
            x: minX - shadowSlack,
            y: renderSize.height - topYUp - shadowSlack,
            width: (maxX - minX) + shadowSlack * 2,
            height: (topYUp - bottomYUp) + shadowSlack * 2
        )
    }
}
