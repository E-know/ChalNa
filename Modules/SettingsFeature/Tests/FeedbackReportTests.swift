import Testing
@testable import SettingsFeature

struct FeedbackReportTests {
    @Test func messageContainsCategoryHeaderAndMeta() {
        let report = FeedbackReport(
            text: "스크롤이 버벅여요",
            category: .bug,
            appVersion: "1.2.0",
            build: "42",
            iosVersion: "18.4",
            deviceModel: "iPhone16,1"
        )
        let msg = report.telegramMessageText
        #expect(msg.contains("🐞 [버그] ChalNa 신고"))
        #expect(msg.contains("스크롤이 버벅여요"))
        #expect(msg.contains("앱 1.2.0 (42) · iOS 18.4 · iPhone16,1"))
    }

    @Test func longTextIsClampedUnderTelegramLimit() {
        let long = String(repeating: "가", count: 5000)
        let report = FeedbackReport(
            text: long,
            category: .other,
            appVersion: "1",
            build: "1",
            iosVersion: "18",
            deviceModel: "x"
        )
        let msg = report.telegramMessageText
        #expect(msg.utf16.count <= 4096)
        #expect(msg.contains("…"))
    }

    /// 이모지(grapheme 1개 = UTF-16 다중유닛)가 많아도 UTF-16 기준 4096 을 넘지 않아야 한다.
    @Test func emojiHeavyTextStaysUnderUTF16Limit() {
        let emoji = String(repeating: "👨‍👩‍👧‍👦", count: 3000) // 가족 이모지 1개 ≈ 11 UTF-16 unit
        let report = FeedbackReport(
            text: emoji,
            category: .bug,
            appVersion: "1",
            build: "1",
            iosVersion: "18",
            deviceModel: "x"
        )
        let msg = report.telegramMessageText
        #expect(msg.utf16.count <= 4096)
    }
}
