import UIKit
import AVFoundation

/// 필름 **표지**의 단일 출처 — 표지는 "재료(첫 클립 원본)"가 아니라
/// **"결과물(합성 mp4)"의 첫 프레임**이다.
///
/// 결과물은 항상 1080×1920(9:16)이므로 이 프레임을 표지로 쓰면
/// 홈/상세의 9:16 포스터 박스와 비율이 일치해 좌우 잘림이 없다(WYSIWYG).
/// 원본 클립 썸네일(16:9·4:3 등)을 표지로 쓰면 scaledToFill 이 좌우를 크게 잘라낸다.
public enum FilmCover {

    /// 표지 JPEG 상한 픽셀 크기. 가장 큰 소비자가 FilmDetail 포스터(240pt, @3x = 720px).
    private static let maxPixelSize = CGSize(width: 720, height: 1280)

    /// 영상 첫 프레임을 표지 JPEG 로 추출한다. 파일이 없거나 추출 실패면 nil —
    /// 폴백(기존 썸네일 유지 등) 판단은 호출처가 한다.
    public static func firstFrameJPEG(fromMovieAt url: URL) async -> Data? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxPixelSize
        guard let result = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: result.image).jpegData(compressionQuality: 0.75)
    }
}
