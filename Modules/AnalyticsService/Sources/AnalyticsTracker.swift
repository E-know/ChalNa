import Foundation

/// Analytics provider 추상화. Feature 는 이 프로토콜에만 의존한다.
public protocol AnalyticsTracker: Sendable {
    /// 이벤트 발사. provider 가 실제 전송 책임을 진다.
    func log(_ event: AnalyticsEvent)

    /// 사용자 속성 설정 (premium 여부 등 활성화 정도 분석용).
    func setUserProperty(_ value: String?, forName name: String)
}

/// Preview · 테스트 · plist 부재 환경에서 사용하는 no-op 구현체.
public struct NoopAnalyticsTracker: AnalyticsTracker {
    public init() {}
    public func log(_ event: AnalyticsEvent) {}
    public func setUserProperty(_ value: String?, forName name: String) {}
}
