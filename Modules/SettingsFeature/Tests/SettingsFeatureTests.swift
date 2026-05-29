import Testing
import ComposableArchitecture
@testable import SettingsFeature

@MainActor
struct SettingsFeatureTests {
    @Test func onAppearIsNoOp() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() }
        await store.send(.onAppear)   // analytics(Noop) 로깅, 상태 불변
    }

    @Test func labelMenuTapIsNoOp() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() }
        await store.send(.labelMenuTapped)   // 네비게이션은 View가 처리 → 상태 불변
    }
}
