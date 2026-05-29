import Testing
@testable import SettingsFeature

struct SettingsModuleSmokeTests {
    @Test func reducerStateInitializes() {
        _ = SettingsFeature.State()
    }
}
