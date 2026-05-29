import Testing
import ComposableArchitecture
import Models
@testable import SettingsFeature

@MainActor
struct SettingsFeatureTests {
    @Test func togglingTimeUpdatesShared() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        store.exhaustivity = .off   // @Shared·appStorage 변경만 결과로 확인
        await store.send(.timeToggled(false))
        #expect(store.state.timeEnabled == false)
    }

    @Test func togglingDateUpdatesShared() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        store.exhaustivity = .off
        await store.send(.dateToggled(false))
        #expect(store.state.dateEnabled == false)
    }

    @Test func positionRowTapsAreNoOpInReducer() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        store.exhaustivity = .off
        await store.send(.timePositionRowTapped)   // 네비게이션은 View가 처리 → 상태 불변
        await store.send(.datePositionRowTapped)
    }

    @Test func timeOpacityUpdatesShared() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() }
        store.exhaustivity = .off
        await store.send(.timeOpacityChanged(0.3))
        #expect(store.state.timeOpacity == 0.3)
    }

    @Test func dateOpacityUpdatesShared() async {
        let store = TestStore(initialState: SettingsFeature.State()) { SettingsFeature() }
        store.exhaustivity = .off
        await store.send(.dateOpacityChanged(0.2))
        #expect(store.state.dateOpacity == 0.2)
    }
}
