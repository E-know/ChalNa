import Foundation
import Testing
@testable import AppCore

struct ExportQuotaTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    @Test func reserveAllowsOneExportPerDay() {
        var ledger = ExportQuotaLedger()
        let first = date(year: 2026, month: 6, day: 1, hour: 9)
        let second = date(year: 2026, month: 6, day: 1, hour: 22)

        #expect(ledger.reserveExport(now: first, calendar: calendar) == .allowed)
        #expect(ledger.reserveExport(now: second, calendar: calendar) == .blocked(.dailyLimit))
        #expect(ledger.exportedAt == [first])
    }

    @Test func reserveAllowsThreeExportsPerWeek() {
        var ledger = ExportQuotaLedger()
        let monday = date(year: 2026, month: 6, day: 1, hour: 9)
        let tuesday = date(year: 2026, month: 6, day: 2, hour: 9)
        let wednesday = date(year: 2026, month: 6, day: 3, hour: 9)
        let thursday = date(year: 2026, month: 6, day: 4, hour: 9)

        #expect(ledger.reserveExport(now: monday, calendar: calendar) == .allowed)
        #expect(ledger.reserveExport(now: tuesday, calendar: calendar) == .allowed)
        #expect(ledger.reserveExport(now: wednesday, calendar: calendar) == .allowed)
        #expect(ledger.reserveExport(now: thursday, calendar: calendar) == .blocked(.weeklyLimit))
        #expect(ledger.exportedAt == [monday, tuesday, wednesday])
    }

    @Test func redeemUnlocksThroughEndOf2026() {
        var ledger = ExportQuotaLedger()
        let now = date(year: 2026, month: 6, day: 1, hour: 9)

        let didRedeem = ledger.redeem(code: "tobyisinho", now: now, calendar: calendar)
        #expect(didRedeem)
        #expect(ledger.isUnlocked(at: date(year: 2026, month: 12, day: 31, hour: 23, minute: 59), calendar: calendar))
        #expect(!ledger.isUnlocked(at: date(year: 2027, month: 1, day: 1, hour: 0), calendar: calendar))
    }

    @Test func redeemRejectsWrongCode() {
        var ledger = ExportQuotaLedger()
        let now = date(year: 2026, month: 6, day: 1, hour: 9)

        let didRedeem = ledger.redeem(code: "wrong", now: now, calendar: calendar)
        #expect(!didRedeem)
        #expect(!ledger.isUnlocked(at: now, calendar: calendar))
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
