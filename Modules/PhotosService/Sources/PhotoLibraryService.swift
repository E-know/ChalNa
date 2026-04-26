import Foundation
import Models

public protocol PhotoLibraryServicing: Sendable {
    /// PhotosPicker의 item identifier 목록을 받아 앱 내부 `Clip` 배열로 해석.
    /// 실제 구현은 `PHAsset.fetchAssets(withLocalIdentifiers:)` + Live Photo 추출.
    func resolve(itemIdentifiers: [String]) async throws -> [Clip]
}

/// PhotoKit 통합 전까지 사용하는 스텁. 요청 개수만큼 SampleData의 클립을 돌려줌.
public actor MockPhotoLibraryService: PhotoLibraryServicing {
    public init() {}

    public func resolve(itemIdentifiers: [String]) async throws -> [Clip] {
        guard !itemIdentifiers.isEmpty else { return [] }
        let pool = SampleData.jejuTimeline
        return (0..<itemIdentifiers.count).map { idx in
            pool[idx % pool.count]
        }
    }
}
