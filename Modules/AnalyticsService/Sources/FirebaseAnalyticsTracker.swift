import Foundation
import FirebaseAnalytics

/// FirebaseAnalytics 백엔드 구현체.
/// `FirebaseApp.configure()` 가 호출된 후에 사용해야 한다 (앱 진입점에서 보장).
public struct FirebaseAnalyticsTracker: AnalyticsTracker {
    public init() {}

    public func log(_ event: AnalyticsEvent) {
        let params = event.parameters.mapValues { $0.firebaseValue }
        Analytics.logEvent(event.name, parameters: params.isEmpty ? nil : params)
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
}

private extension AnalyticsParameterValue {
    /// FirebaseAnalytics 가 받아들이는 NSObject value 로 변환.
    var firebaseValue: NSObject {
        switch self {
        case let .string(s): return s as NSString
        case let .int(i):    return NSNumber(value: i)
        case let .double(d): return NSNumber(value: d)
        case let .bool(b):   return NSNumber(value: b)
        }
    }
}
