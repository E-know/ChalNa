import ComposableArchitecture

@Reducer
public struct SettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case onAppear
    }

    public var body: some ReducerOf<Self> {
        Reduce { _, _ in .none }
    }
}
