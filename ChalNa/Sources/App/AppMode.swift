import Foundation

enum AppMode {
    case real
    case devMock

    static var current: AppMode {
        #if DEBUG
        if ProcessInfo.processInfo.environment["CHALNA_APP_MODE"] == "devMock" {
            return .devMock
        }
        #endif
        return .real
    }
}

extension AppMode {
    /// DEBUG 전용. `CHALNA_APP_MODE=showcase` 로 실행하면 앱 대신
    /// 디자인 시스템 쇼케이스를 띄운다 — P1 컴포넌트의 시각 검증 경로.
    ///
    /// enum 케이스가 아니라 별도 플래그인 이유: `AppMode` 에 케이스를 더하면
    /// `AppFeature` 의 `.real`/`.devMock` switch 가 비망라가 되어 그쪽까지 손대야 한다.
    static var isShowcase: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["CHALNA_APP_MODE"] == "showcase"
        #else
        return false
        #endif
    }
}
