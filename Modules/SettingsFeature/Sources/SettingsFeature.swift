import ComposableArchitecture
import AnalyticsService
import AppCore
import Models

/// 설정 목록과 상세 영역의 선택 및 상태를 함께 관리한다.
@Reducer
public struct SettingsFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        var selectedSection: Section?
        var outputResolution = FilmOutputResolution.fullHD
        var language = LanguageFeature.State()
        var support = SupportFeature.State()

        public init() {}
    }

    public enum Section: Hashable {
        case language
        case support
    }

    public enum Action {
        case onAppear
        case sectionSelected(Section?)
        case outputResolutionSelected(FilmOutputResolution)
        case language(LanguageFeature.Action)
        case support(SupportFeature.Action)
    }

    @Dependency(\.analyticsTracker) var analyticsTracker
    @Dependency(\.filmOutputResolution) var filmOutputResolution

    public var body: some ReducerOf<Self> {
        Scope(state: \.language, action: \.language) { LanguageFeature() }
        Scope(state: \.support, action: \.support) { SupportFeature() }
        Reduce { state, action in
            switch action {
            case .onAppear:
                analyticsTracker.log(.settingsOpened)
                state.outputResolution = filmOutputResolution.get()
                return .none
            case let .sectionSelected(section):
                state.selectedSection = section
                return .none
            case let .outputResolutionSelected(resolution):
                state.outputResolution = resolution
                filmOutputResolution.set(resolution)
                return .none
            case .support(.delegate(.finished)):
                if state.selectedSection == .support { state.selectedSection = nil }
                return .none
            case .language, .support:
                return .none
            }
        }
    }
}
