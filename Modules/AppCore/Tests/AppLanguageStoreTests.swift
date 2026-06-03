import Testing
import Foundation
@testable import AppCore

@MainActor
struct AppLanguageStoreTests {
    private func freshDefaults() {
        UserDefaults.standard.removeObject(forKey: AppLanguageStore.storageKey)
    }

    @Test func defaultsToSystemWhenUnset() {
        freshDefaults()
        let store = AppLanguageStore()
        #expect(store.language == .system)
    }

    @Test func persistsAndRestoresSelection() {
        freshDefaults()
        let store = AppLanguageStore()
        store.set(.ja)
        #expect(store.language == .ja)
        #expect(UserDefaults.standard.string(forKey: AppLanguageStore.storageKey) == "ja")
        // 새 인스턴스가 저장값을 복원
        let restored = AppLanguageStore()
        #expect(restored.language == .ja)
        freshDefaults()
    }

    @Test func localeMapping() {
        #expect(AppLanguage.en.locale.identifier == "en")
        #expect(AppLanguage.ja.locale.identifier == "ja")
        #expect(AppLanguage.system.bundleCode == nil)
        #expect(AppLanguage.ko.bundleCode == "ko")
    }

    @Test func isKoreanUIForExplicitSelection() {
        freshDefaults()
        let store = AppLanguageStore()
        store.set(.ko)
        #expect(store.isKoreanUI == true)
        store.set(.en)
        #expect(store.isKoreanUI == false)
        store.set(.ja)
        #expect(store.isKoreanUI == false)
        store.set(.system) // 스위즐 원복
        freshDefaults()
    }

    @Test func displayNamesAreNonEmpty() {
        for lang in AppLanguage.allCases {
            #expect(!lang.displayName.isEmpty)
        }
    }
}
