import AppCore
import ComposableArchitecture

@Reducer
public struct LanguageFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action: Equatable {
        case selected(AppLanguage)
    }

    @Dependency(\.appLanguageWriter) var writer

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case let .selected(language):
                return .run { _ in await writer.set(language) }
            }
        }
    }
}
