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

    @Test func reserveAllowsTwoExportsPerDay() {
        var ledger = ExportQuotaLedger()
        let first = date(year: 2026, month: 6, day: 1, hour: 9)
        let second = date(year: 2026, month: 6, day: 1, hour: 17)
        let third = date(year: 2026, month: 6, day: 1, hour: 22)

        #expect(ledger.reserveExport(now: first, calendar: calendar) == .allowed)
        #expect(ledger.checkExport(now: second, calendar: calendar) == .allowed)
        #expect(ledger.exportedAt == [first])
        #expect(ledger.reserveExport(now: second, calendar: calendar) == .allowed)
        #expect(ledger.checkExport(now: third, calendar: calendar) == .blocked(.dailyLimit))
        #expect(ledger.reserveExport(now: third, calendar: calendar) == .blocked(.dailyLimit))
        #expect(ledger.exportedAt == [first, second])
    }

    @Test func reserveAllowsFiveExportsPerWeek() {
        var ledger = ExportQuotaLedger()
        let firstFive = (1...5).map { date(year: 2026, month: 6, day: $0, hour: 9) }
        let sixth = date(year: 2026, month: 6, day: 6, hour: 9)

        for time in firstFive {
            #expect(ledger.reserveExport(now: time, calendar: calendar) == .allowed)
        }
        #expect(ledger.checkExport(now: sixth, calendar: calendar) == .blocked(.weeklyLimit))
        #expect(ledger.reserveExport(now: sixth, calendar: calendar) == .blocked(.weeklyLimit))
        #expect(ledger.exportedAt == firstFive)
    }

    @Test func checkUsesTheNewWeekWithoutPruningPersistedExports() throws {
        let previousWeek = (3...7).map { date(year: 2026, month: 6, day: $0, hour: 9) }
        let persisted = try JSONSerialization.data(withJSONObject: [
            "exportedAt": previousWeek.map(\.timeIntervalSinceReferenceDate),
        ])
        let storedLedger = try JSONDecoder().decode(ExportQuotaLedger.self, from: persisted)
        let sunday = date(year: 2026, month: 6, day: 7, hour: 23, minute: 59)
        let monday = date(year: 2026, month: 6, day: 8, hour: 0)

        #expect(storedLedger.checkExport(now: sunday, calendar: calendar) == .blocked(.weeklyLimit))
        #expect(storedLedger.checkExport(now: monday, calendar: calendar) == .allowed)
        #expect(storedLedger.exportedAt == previousWeek)

        var ledger = storedLedger
        #expect(ledger.reserveExport(now: monday, calendar: calendar) == .allowed)
        #expect(ledger.exportedAt == [monday])
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
