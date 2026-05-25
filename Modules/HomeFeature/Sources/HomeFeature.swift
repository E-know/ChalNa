import ComposableArchitecture
import Foundation

/// 홈 화면의 Reducer. 가장 단순한 Feature 라 TCA 패턴 검증 용도로 먼저 마이그레이션.
/// Note: SwiftData `@Query films` 는 TCA State 에 두지 않고 View 에 그대로 둔다
/// (TCA + SwiftData 공식 권장 패턴).
@Reducer
public struct HomeFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var scrollProgress: Double = 0
        public init(scrollProgress: Double = 0) {
            self.scrollProgress = scrollProgress
        }
    }

    public enum Action {
        case newVlogButtonTapped
        case settingsButtonTapped
        case scrollProgressChanged(Double)
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .newVlogButtonTapped:
                // 부모(현재는 RootView, 추후 AppFeature) 가 navigation 처리.
                return .none

            case .settingsButtonTapped:
                // 향후 설정 화면 진입.
                return .none

            case let .scrollProgressChanged(progress):
                let clamped = max(0, min(1, progress))
                guard abs(clamped - state.scrollProgress) > 0.01 else { return .none }
                state.scrollProgress = clamped
                return .none
            }
        }
    }
}
