import Foundation

/// 삭제된 기능이 남긴 `UserDefaults` 키를 앱 시작 시 한 번 지운다.
///
/// **왜 필요한가**: `@Shared(.appStorage(...))` 로 저장된 값은 코드에서 읽는 쪽이 사라져도
/// 사용자 기기의 defaults plist 에 영원히 남는다. 읽는 사람이 없으니 당장은 무해하지만,
/// 나중에 다른 기능이 같은 키 이름을 재사용하면 **이전 버전이 남긴 쓰레기 값을 그대로 물려받는다**
/// (예: `labelTimeEnabled` 를 Bool 로 썼는데 새 기능이 다른 의미로 쓰는 경우).
/// 이름 충돌은 컴파일러도 테스트도 못 잡으므로, 기능을 지울 때 키도 같이 지우는 게 유일한 방어다.
public enum RemovedSettingsCleanup {

    /// 라벨 설정 화면(시각/날짜 라벨 on-off · 9구역 위치 · 불투명도)이 남긴 키.
    /// 라벨은 이제 우측 하단 고정 · 불투명도 0.75 로 항상 켜져 있고 설정 화면 자체가 없다.
    static let removedKeys = [
        "labelTimeEnabled",
        "labelTimePosition",
        "labelTimeOpacity",
        "labelDateEnabled",
        "labelDatePosition",
        "labelDateOpacity",
    ]

    /// 남아 있는 폐기 키를 제거하고, 실제로 지운 키를 돌려준다(테스트·진단용).
    /// 멱등이라 매 실행 호출해도 안전하다 — 두 번째부터는 지울 게 없어 빈 배열을 반환한다.
    @discardableResult
    public static func run(_ defaults: UserDefaults = .standard) -> [String] {
        var removed: [String] = []
        for key in removedKeys where defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
            removed.append(key)
        }
        return removed
    }
}
