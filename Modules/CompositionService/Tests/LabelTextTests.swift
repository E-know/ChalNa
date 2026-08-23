import Testing
import Foundation
import CoreGraphics
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import Models

/// 자동 라벨의 **문자열·폰트·실측** SSOT(`LabelText`) 계약.
///
/// 이 PR 이전에는 로케일 해석·포매터 2개·폰트가 CompositionService 와 AutoLabelsOverlay 에
/// 그대로 복제돼 있었고 동기화 수단이 주석뿐이었다 — 한쪽만 고쳐도 컴파일·테스트가 조용했다.
/// 이제 두 렌더 경로가 같은 함수를 부르므로 여기서 그 함수의 계약만 고정하면 된다.
struct LabelTextTests {

    /// 로케일별 형식은 영상에 그대로 새겨진다. 바꾸면 이미 내보낸 영상과 달라진다.
    @Test func formatsDifferByLocale() {
        // 2026-08-23 14:05 KST 고정 — 타임존 의존을 없애려고 formatter 와 같은 .current 로 만든다.
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 23; c.hour = 14; c.minute = 5
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let date = cal.date(from: c)!

        #expect(LabelText.timeString(date, locale: Locale(identifier: "ko")) == "14:05")
        #expect(LabelText.timeString(date, locale: Locale(identifier: "ja")) == "14:05")
        #expect(LabelText.dateString(date, locale: Locale(identifier: "ko")) == "2026/08/23")
        #expect(LabelText.dateString(date, locale: Locale(identifier: "ja")) == "2026/08/23")

        // en 만 12시간 + MM/dd/yyyy.
        let enTime = LabelText.timeString(date, locale: Locale(identifier: "en"))
        #expect(enTime.hasPrefix("2:05"), "en 은 12시간제여야 함: \(enTime)")
        #expect(LabelText.dateString(date, locale: Locale(identifier: "en")) == "08/23/2026")
    }

    /// `appLanguage` 미설정이면 시스템 로케일. 스위즐은 Bundle 만 바꾸므로 여기서 직접 읽어야 한다.
    @Test func localeFollowsAppLanguageKey() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: "appLanguage")
        defer {
            if let saved { defaults.set(saved, forKey: "appLanguage") }
            else { defaults.removeObject(forKey: "appLanguage") }
        }

        defaults.set("ja", forKey: "appLanguage")
        #expect(LabelText.locale().language.languageCode?.identifier == "ja")
        defaults.set("en", forKey: "appLanguage")
        #expect(LabelText.locale().language.languageCode?.identifier == "en")
    }

    #if canImport(UIKit)
    /// SwiftUI 짝과 UIKit 짝이 같은 폰트여야 한다 — 미리보기는 `font(px:)` 로 그리고
    /// 레이아웃은 `uiFont(px:)` 실측으로 잡으므로, 어긋나면 우측 정렬 스탬프가 밀린다.
    /// (구 `ChalNaTypography.fixed(_:weight:)`/`fixedUIFont(_:)` 가 정확히 이 비대칭이었다.)
    @Test func swiftUIAndUIKitFontsAgree() {
        #expect(LabelText.font(px: 49) == Font.system(size: 49, weight: LabelText.weight, design: .default))

        let ui = LabelText.uiFont(px: 49)
        #expect(ui.pointSize == 49)
        #expect(ui.familyName == UIFont.systemFont(ofSize: 49, weight: LabelText.uiWeight).familyName)

        let traits = ui.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        let weight = traits?[.weight] as? CGFloat
        #expect(weight == LabelText.uiWeight.rawValue, "UIKit 짝의 굵기가 uiWeight 와 달라졌다: \(String(describing: weight))")
        #expect(LabelText.uiWeight == .bold)
        #expect(LabelText.weight == .bold)
    }

    /// 실측은 폰트 크기에 단조 증가해야 한다(ceil 때문에 동률은 허용 안 함).
    @Test func measureGrowsWithPointSize() {
        let small = LabelText.measure("2026/08/23", px: 20)
        let large = LabelText.measure("2026/08/23", px: 40)
        #expect(large.width > small.width)
        #expect(large.height > small.height)
    }
    #endif

    /// 1080×1920 에서 시각+날짜 스택이 **패딩 안에 실제로 들어가는지**.
    /// 구 `fontFractionsAreCornerStampSized` 는 분수 리터럴을 자기 선언과 대조하는
    /// change-detector 라, 분수를 잘못된 차원에 곱하거나 라벨이 캔버스를 벗어나도 통과했다.
    @Test func stampFitsInsidePaddedCanvas() {
        let canvas = CGSize(width: 1080, height: 1920)
        let date = Date(timeIntervalSince1970: 1_787_000_000)
        let rect = LabelText.stampRect(renderSize: canvas, capturedAt: date, locale: Locale(identifier: "ko"))

        let padX = canvas.width * LabelLayout.paddingFraction
        let padY = canvas.height * LabelLayout.paddingFraction
        let slack = LabelText.shadowSlack   // 그림자만 패딩 밖으로 번질 수 있다

        #expect(rect.minX >= 0 && rect.minY >= 0, "캔버스 밖으로 나감: \(rect)")
        #expect(rect.maxX <= canvas.width - padX + slack, "우측 여백 침범: \(rect)")
        #expect(rect.maxY <= canvas.height - padY + slack, "하단 여백 침범: \(rect)")

        // 코너 "스탬프" — 캔버스를 가리면 안 된다. (구 0.18 분수 시절엔 폭이 캔버스를 넘겼다.)
        #expect(rect.width < canvas.width * 0.5, "코너 스탬프가 너무 넓다: \(rect.width)")
        #expect(rect.height < canvas.height * 0.15, "코너 스탬프가 너무 높다: \(rect.height)")

        // 시각이 날짜보다 커야 위계가 산다.
        #expect(LabelLayout.timeFontFraction > LabelLayout.dateFontFraction)
    }
}
