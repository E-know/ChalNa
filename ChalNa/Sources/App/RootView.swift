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

/// 앱 루트. TCA AppFeature가 편집 스택과 설정 화면 표시를 관리한다.
public struct RootView: View {
    @State private var store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    /// Reducer(@Dependency)와 View(environment)가 같은 인스턴스를 공유한다.
    @Dependency(\.editSession) private var session
    @Environment(AppLanguageStore.self) private var languageStore

    public init() {}

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            HomeView(store: store.scope(state: \.home, action: \.home))
        } destination: { childStore in
            destinationView(for: childStore)
        }
        .fullScreenCover(item: $store.scope(\.settings, action: \.settings)) { settingsStore in
            SettingsView(store: settingsStore)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .alert($store.scope(\.quotaAlert, action: \.quotaAlert))
        .environment(session)
        .environment(\.locale, languageStore.locale)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    @ViewBuilder
    private func destinationView(for childStore: StoreOf<AppFeature.Path>) -> some View {
        switch childStore.case {
        case let .mediaPicker(s): MediaPickerView(store: s)
        case let .timeline(s):    TimelineView(store: s)
        case let .export(s):      ExportView(store: s)
        case let .filmDetail(s):  FilmDetailView(store: s)
        case let .clipAdjust(s):    ClipAdjustView(store: s)
        }
    }
}

#Preview {
    RootView().environment(AppLanguageStore())
}
