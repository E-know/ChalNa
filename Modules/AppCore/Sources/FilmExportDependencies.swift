import ComposableArchitecture
import Foundation
import Models

// 실제 구현은 앱 시작 시 주입한다. 테스트와 미리보기는 사진 보관함을 건드리지 않는다.
private enum ComposerKey: TestDependencyKey {
    static let testValue: any FilmComposing = UnavailableComposer()

    private struct UnavailableComposer: FilmComposing {
        func export(clips: [Clip], rotations: [Clip.ID: ClipRotation],
                    transforms: [Clip.ID: ClipTransform], clipLabels: [Clip.ID: ClipLabel]) -> AsyncStream<FilmExportEvent> {
            AsyncStream { stream in
                stream.yield(.failed(CocoaError(.featureUnsupported).localizedDescription))
                stream.finish()
            }
        }
    }
}

private enum PhotoWriterKey: TestDependencyKey {
    static let testValue: any FilmPhotoWriting = UnavailableWriter()

    private struct UnavailableWriter: FilmPhotoWriting {
        func saveVideo(at url: URL) async -> FilmPhotoSaveResult { .denied }
    }
}

public extension DependencyValues {
    var filmComposer: any FilmComposing {
        get { self[ComposerKey.self] }
        set { self[ComposerKey.self] = newValue }
    }

    var photoWriter: any FilmPhotoWriting {
        get { self[PhotoWriterKey.self] }
        set { self[PhotoWriterKey.self] = newValue }
    }
}
