import Testing
import ComposableArchitecture
@testable import SettingsFeature

@MainActor
struct SettingsFeatureTests {
    @Test func onAppearIsNoOp() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() }
        await store.send(.onAppear)   // analytics(Noop) 로깅, 상태 불변
    }

    @Test func labelMenuTapEmitsDelegate() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() }
        await store.send(.labelMenuTapped)
        await store.receive(.delegate(.labelSettingsRequested))   // 화면 전환은 부모(AppFeature)가 해석
    }

    @Test func languageMenuTapEmitsDelegate() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() }
        await store.send(.languageMenuTapped)
        await store.receive(.delegate(.languageRequested))
    }

    @Test func supportMenuTapEmitsDelegate() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() }
        await store.send(.supportMenuTapped)
        await store.receive(.delegate(.supportRequested))
    }
}
