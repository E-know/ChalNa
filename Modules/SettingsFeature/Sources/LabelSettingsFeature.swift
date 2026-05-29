import ComposableArchitecture
import Models
import AnalyticsService

@Reducer
public struct LabelSettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        @Shared(.appStorage("labelTimeEnabled")) public var timeEnabled = true
        @Shared(.appStorage("labelTimePosition")) public var timePosition = LabelPosition.center
        @Shared(.appStorage("labelTimeOpacity")) public var timeOpacity = 0.5
        @Shared(.appStorage("labelDateEnabled")) public var dateEnabled = true
        @Shared(.appStorage("labelDatePosition")) public var datePosition = LabelPosition.bottomCenter
        @Shared(.appStorage("labelDateOpacity")) public var dateOpacity = 1.0
        public init() {}
    }

    public enum Action {
        case timeToggled(Bool)
        case dateToggled(Bool)
        case timePositionRowTapped
        case datePositionRowTapped
        case timeOpacityChanged(Double)
        case dateOpacityChanged(Double)
    }

    @Dependency(\.analyticsTracker) var analyticsTracker

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
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
            case let .timeOpacityChanged(value):
                state.$timeOpacity.withLock { $0 = value }
                return .none
            case let .dateOpacityChanged(value):
                state.$dateOpacity.withLock { $0 = value }
                return .none
            }
        }
    }
}
