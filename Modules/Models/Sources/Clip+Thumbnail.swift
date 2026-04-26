import SwiftUI

public extension Clip {
    /// 사용자가 PhotosPicker에서 고른 실사진/영상 썸네일이 있으면 그걸 그리고,
    /// 없으면 디자인 프리셋 그라디언트를 fallback으로 그린다.
    /// - Parameter contentMode: 부모 프레임에 대한 채움 방식. 기본 `.fill` (FilmStrip 등).
    ///   고정 크기 프리뷰처럼 letterbox가 필요한 곳은 `.fit` 으로 호출.
    @ViewBuilder
    func thumbnailView(contentMode: ContentMode = .fill) -> some View {
        if let data = thumbnailData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            preset.view()
        }
    }
}
