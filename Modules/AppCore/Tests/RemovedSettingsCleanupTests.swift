import Testing
import Foundation
@testable import AppCore

/// 삭제된 라벨 설정이 남긴 UserDefaults 키가 실제로 지워지는지.
/// 키 목록이 비거나 오타가 나면 조용히 아무것도 안 지우므로(그래도 앱은 잘 뜬다) 여기서 고정한다.
struct RemovedSettingsCleanupTests {

    /// 테스트끼리 간섭하지 않게 매번 고유 suite 를 쓴다.
    private func makeDefaults() -> UserDefaults {
        let name = "RemovedSettingsCleanupTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func removesEveryRetiredLabelKey() {
        let defaults = makeDefaults()
        for key in RemovedSettingsCleanup.removedKeys {
            defaults.set("stale", forKey: key)
        }

        let removed = RemovedSettingsCleanup.run(defaults)

        #expect(Set(removed) == Set(RemovedSettingsCleanup.removedKeys))
        for key in RemovedSettingsCleanup.removedKeys {
            #expect(defaults.object(forKey: key) == nil, "\(key) 가 남아 있으면 안 된다")
        }
    }

    /// 라벨 설정 화면이 실제로 쓰던 6개 키가 목록에 다 들어 있는지 — 하나라도 빠지면 그 키만 영구히 남는다.
    @Test func keyListCoversAllSixRetiredSettings() {
        #expect(Set(RemovedSettingsCleanup.removedKeys) == [
            "labelTimeEnabled", "labelTimePosition", "labelTimeOpacity",
            "labelDateEnabled", "labelDatePosition", "labelDateOpacity",
        ])
    }

    /// 멱등: 두 번째 실행은 지울 게 없다. 관련 없는 키는 건드리지 않는다.
    @Test func isIdempotentAndLeavesOtherKeysAlone() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "labelTimeEnabled")
        defaults.set("ko", forKey: AppLanguageStore.storageKey)

        #expect(RemovedSettingsCleanup.run(defaults) == ["labelTimeEnabled"])
        #expect(RemovedSettingsCleanup.run(defaults).isEmpty)
        #expect(defaults.string(forKey: AppLanguageStore.storageKey) == "ko", "언어 설정은 살아 있어야 한다")
    }
}
