import SwiftUI
import ComposableArchitecture
import TimelineFeature
import ExportFeature
import MediaPickerFeature
import HomeFeature
import FilmDetailFeature
import AppCore
import DesignSystem
import SettingsFeature

/// 앱 루트. TCA AppFeature 의 StackState 가 navigation 의 단일 출처.
/// push 는 자식 delegate → AppFeature, pop 은 자식 리듀서의 dismiss 의존성이 처리한다.
public struct RootView: View {
    @State private var store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    /// Reducer(@Dependency)와 View(environment)가 같은 인스턴스를 공유한다.
    @Dependency(\.editSession) private var session
    @State private var languageStore = AppLanguageStore()

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
        .environment(session)
        .environment(languageStore)
        .environment(\.locale, languageStore.locale)
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
        case let .labelPosition(s): LabelPositionSettingsView(store: s)
        case let .support(s):       SupportView(store: s)
        case let .clipAdjust(s):    ClipAdjustView(store: s)
        case let .language(s):      LanguageView(store: s)
        }
    }
}

#Preview {
    RootView()
}
