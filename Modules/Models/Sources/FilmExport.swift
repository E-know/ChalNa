import Foundation

public enum FilmExportEvent: Sendable {
    case progress(Double)
    case completed(URL)
    case failed(String)
}

public protocol FilmComposing: Sendable {
    func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        transforms: [Clip.ID: ClipTransform],
        clipLabels: [Clip.ID: ClipLabel],
        resolution: FilmOutputResolution
    ) -> AsyncStream<FilmExportEvent>
}

public extension FilmComposing {
    func export(
        clips: [Clip],
        rotations: [Clip.ID: ClipRotation],
        transforms: [Clip.ID: ClipTransform],
        clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<FilmExportEvent> {
        export(clips: clips, rotations: rotations, transforms: transforms, clipLabels: clipLabels, resolution: .fullHD)
    }
}

public enum FilmPhotoSaveResult: Equatable, Sendable {
    case ok(localIdentifier: String)
    case denied
    case failed(String)
}

public enum PhotoVideoAvailability: Equatable, Sendable {
    case available
    case missing
    case authorizationRequired
    case accessRequired
}

public protocol FilmPhotoWriting: Sendable {
    func saveVideo(at url: URL) async -> FilmPhotoSaveResult
}
