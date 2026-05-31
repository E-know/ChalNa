import SwiftUI
import ComposableArchitecture
import TimelineFeature
import ExportFeature
import MediaPickerFeature
import HomeFeature
import FilmDetailFeature
import AppCore
import DesignSystem
import PhotosService
import Models
import SettingsFeature

/// 앱 루트. TCA AppFeature 의 StackState 로 navigation 을 통합. AppRouter 는 호환용 thin wrapper.
public struct RootView: View {
    @State private var store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    @State private var router = AppRouter()
    @State private var session = EditSession()

    public init() {}

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            HomeView(store: store.scope(state: \.home, action: \.home))
                .toolbar(.hidden, for: .navigationBar)
                .chalNaSwipeBack()
        } destination: { childStore in
            destinationView(for: childStore)
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
                .chalNaSwipeBack()
        }
        .environment(router)
        .environment(session)
        .onAppear { wireRouterHandlers() }
    }

    @ViewBuilder
    private func destinationView(for childStore: StoreOf<AppFeature.Path>) -> some View {
        switch childStore.case {
        case let .mediaPicker(s): MediaPickerView(store: s)
        case let .timeline(s):    TimelineView(store: s)
        case let .export(s):      ExportView(store: s)
        case let .filmDetail(s):  FilmDetailView(store: s)
        case let .settings(s):      SettingsView(store: s)
        case let .labelSettings(s): LabelSettingsView(store: s)
        case let .labelPosition(s): LabelPositionPickerView(store: s)
        case let .support(s):       SupportView(store: s)
        }
    }

    private func wireRouterHandlers() {
        router.pushHandler = { [store] route in
            switch route {
            case .mediaPicker:
                store.send(.routerPushedMediaPicker(source: currentMediaPickerSource))
            case .timeline:
                store.send(.routerPushedTimeline)
            case .export:
                store.send(.routerPushedExport)
            case let .filmDetail(filmID):
                store.send(.routerPushedFilmDetail(filmID: filmID))
            case .settings:
                store.send(.routerPushedSettings)
            case .labelSettings:
                store.send(.routerPushedLabelSettings)
            case let .labelPosition(kind):
                store.send(.routerPushedLabelPosition(kind: kind))
            case .support:
                store.send(.routerPushedSupport)
            }
        }
        router.popHandler = { [store] in store.send(.routerPopped) }
        router.popToRootHandler = { [store] in store.send(.routerPoppedToRoot) }
    }

    private var currentMediaPickerSource: MediaPickerSource {
        switch AppMode.current {
        case .real:
            return .photoLibrary
        case .devMock:
            return .devFixtures(BundledDevMediaSource())
        }
    }
}

#Preview {
    RootView()
}
