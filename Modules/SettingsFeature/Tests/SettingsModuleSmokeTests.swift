import Testing
import Dependencies
@testable import SettingsFeature

struct SettingsModuleSmokeTests {
    @Test func reducerStateInitializes() {
        withDependencies {
            $0.appStorageKeyFormatWarningEnabled = false
        } operation: {
            _ = SettingsFeature.State()
        }
    }
}
