import ComposableArchitecture
import Models
import AnalyticsService

@Reducer
public struct SettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        @Shared(.appStorage("labelTimeEnabled")) public var timeEnabled = true
        @Shared(.appStorage("labelTimePosition")) public var timePosition = LabelPosition.center
        @Shared(.appStorage("labelDateEnabled")) public var dateEnabled = true
        @Shared(.appStorage("labelDatePosition")) public var datePosition = LabelPosition.bottomCenter

        public init() {}
    }

    public enum Action {
        case onAppear
        case timeToggled(Bool)
        case dateToggled(Bool)
        // 네비게이션 intent — View 가 router.push(.labelPosition(kind)) 처리
        case timePositionRowTapped
        case datePositionRowTapped
    }

    @Dependency(\.analyticsTracker) var analyticsTracker

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                analyticsTracker.log(.settingsOpened)
                return .none

            case let .timeToggled(on):
                state.$timeEnabled.withLock { $0 = on }
                analyticsTracker.log(.labelToggled(kind: LabelKind.time.rawValue, on: on))
                return .none

            case let .dateToggled(on):
                state.$dateEnabled.withLock { $0 = on }
                analyticsTracker.log(.labelToggled(kind: LabelKind.date.rawValue, on: on))
                return .none

            case .timePositionRowTapped, .datePositionRowTapped:
                return .none
            }
        }
    }
}
