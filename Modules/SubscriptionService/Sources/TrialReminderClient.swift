import ComposableArchitecture
import Foundation
import UserNotifications

/// 체험 종료 D-2 로컬 알림. 페이월 타임라인의 "2일차 — 종료 전 알림" 약속을 이행한다.
/// 알림 권한 요청도 이 맥락("종료 전에 알려드려요")에서 수행한다.
@DependencyClient
public struct TrialReminderClient: Sendable {
    /// 권한 요청 후 체험 시작 2일 뒤 알림 예약. 반환값 = 권한 허용 여부.
    public var scheduleTrialEndingReminder: @Sendable (_ priceText: String) async -> Bool = { _ in false }
}

extension TrialReminderClient: DependencyKey {
    public static let liveValue = TrialReminderClient(
        scheduleTrialEndingReminder: { priceText in
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return false }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "찰나 무료 체험이 곧 끝나요")
            content.body = String(localized: "내일 \(priceText)/주 구독이 시작돼요. 원치 않으면 지금 취소할 수 있어요.")
            content.sound = .default

            // 체험 3일 중 2일차 시점 (48시간 뒤).
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 48, repeats: false)
            let request = UNNotificationRequest(
                identifier: "trial-ending-reminder",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
            return true
        }
    )

    public static let testValue = TrialReminderClient()
}

public extension DependencyValues {
    var trialReminderClient: TrialReminderClient {
        get { self[TrialReminderClient.self] }
        set { self[TrialReminderClient.self] = newValue }
    }
}
