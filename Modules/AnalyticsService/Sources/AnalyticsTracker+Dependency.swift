import ComposableArchitecture
import Foundation

/// TCA `@Dependency(\.analyticsTracker)` 로 주입할 수 있게 등록.
/// - liveValue: 앱 진입점에서 FirebaseAnalyticsTracker 로 override.
/// - testValue / previewValue: Noop (이벤트 무시).
private enum AnalyticsTrackerKey: DependencyKey {
    static let liveValue: any AnalyticsTracker = NoopAnalyticsTracker()
    static let testValue: any AnalyticsTracker = NoopAnalyticsTracker()
    static let previewValue: any AnalyticsTracker = NoopAnalyticsTracker()
}

public extension DependencyValues {
    var analyticsTracker: any AnalyticsTracker {
        get { self[AnalyticsTrackerKey.self] }
        set { self[AnalyticsTrackerKey.self] = newValue }
    }
}
