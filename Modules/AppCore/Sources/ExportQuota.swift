import ComposableArchitecture
import Foundation

public enum ExportQuotaDecision: Equatable, Sendable {
    case allowed
    case blocked(ExportQuotaBlockReason)
}

public enum ExportQuotaBlockReason: Equatable, Sendable {
    case dailyLimit
    case weeklyLimit

    public var message: String {
        switch self {
        case .dailyLimit:
            return String(localized: "영상 생성은 하루에 1번만 할 수 있어요.")
        case .weeklyLimit:
            return String(localized: "영상 생성은 일주일에 3번까지만 할 수 있어요.")
        }
    }
}

public struct ExportQuotaLedger: Equatable, Codable, Sendable {
    public private(set) var exportedAt: [Date]
    public private(set) var unlockExpiresAt: Date?

    public init(exportedAt: [Date] = [], unlockExpiresAt: Date? = nil) {
        self.exportedAt = exportedAt
        self.unlockExpiresAt = unlockExpiresAt
    }

    public func isUnlocked(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard let unlockExpiresAt else { return false }
        return now <= unlockExpiresAt
    }

    @discardableResult
    public mutating func reserveExport(now: Date, calendar: Calendar = .autoupdatingCurrent) -> ExportQuotaDecision {
        guard !isUnlocked(at: now, calendar: calendar) else { return .allowed }

        prune(toWeekContaining: now, calendar: calendar)

        let exportsToday = exportedAt.filter { calendar.isDate($0, inSameDayAs: now) }.count
        guard exportsToday < 1 else { return .blocked(.dailyLimit) }

        guard exportedAt.count < 3 else { return .blocked(.weeklyLimit) }

        exportedAt.append(now)
        return .allowed
    }

    @discardableResult
    public mutating func redeem(code: String, now: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized == Self.redeemCode else { return false }
        unlockExpiresAt = Self.unlockEndDate(calendar: calendar)
        return isUnlocked(at: now, calendar: calendar)
    }

    private mutating func prune(toWeekContaining now: Date, calendar: Calendar) {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            exportedAt = exportedAt.filter { calendar.isDate($0, inSameDayAs: now) }
            return
        }
        exportedAt = exportedAt.filter { week.contains($0) }
    }

    private static let redeemCode = "tobyisinho"

    private static func unlockEndDate(calendar: Calendar) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 12
        components.day = 31
        components.hour = 23
        components.minute = 59
        components.second = 59
        return components.date ?? Date(timeIntervalSince1970: 1_798_761_599)
    }
}

@DependencyClient
public struct ExportQuotaClient: Sendable {
    public var reserveExport: @Sendable () -> ExportQuotaDecision = { .allowed }
    public var redeem: @Sendable (_ code: String) -> Bool = { _ in false }
}

extension ExportQuotaClient: DependencyKey {
    public static let liveValue = ExportQuotaClient(
        reserveExport: {
            ExportQuotaUserDefaults.reserveExport()
        },
        redeem: { code in
            ExportQuotaUserDefaults.redeem(code: code)
        }
    )

    public static let testValue = ExportQuotaClient()
}

public extension DependencyValues {
    var exportQuotaClient: ExportQuotaClient {
        get { self[ExportQuotaClient.self] }
        set { self[ExportQuotaClient.self] = newValue }
    }
}

private enum ExportQuotaUserDefaults {
    private static let storageKey = "exportQuotaLedger.v1"

    static func reserveExport() -> ExportQuotaDecision {
        var ledger = load()
        let decision = ledger.reserveExport(now: Date())
        save(ledger)
        return decision
    }

    static func redeem(code: String) -> Bool {
        var ledger = load()
        let didRedeem = ledger.redeem(code: code, now: Date())
        if didRedeem { save(ledger) }
        return didRedeem
    }

    private static func load() -> ExportQuotaLedger {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let ledger = try? JSONDecoder().decode(ExportQuotaLedger.self, from: data) else {
            return ExportQuotaLedger()
        }
        return ledger
    }

    private static func save(_ ledger: ExportQuotaLedger) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
