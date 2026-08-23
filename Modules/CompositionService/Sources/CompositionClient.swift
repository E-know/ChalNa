import Foundation
import ComposableArchitecture
import Models

/// AVFoundationCompositionService 를 TCA @DependencyClient 로 노출한 형태.
@DependencyClient
public struct CompositionClient: Sendable {
    public var export: @Sendable (
        _ clips: [Clip],
        _ rotations: [Clip.ID: ClipRotation],
        _ transforms: [Clip.ID: ClipTransform],
        _ clipLabels: [Clip.ID: ClipLabel]
    ) -> AsyncStream<ExportEvent> = { _, _, _, _ in
        AsyncStream { $0.finish() }
    }
}

extension CompositionClient: DependencyKey {
    public static let liveValue: CompositionClient = {
        let service = AVFoundationCompositionService()
        return CompositionClient(
            export: { clips, rotations, transforms, clipLabels in
                service.export(clips: clips, rotations: rotations, transforms: transforms, clipLabels: clipLabels)
            }
        )
    }()

    public static let testValue = CompositionClient()
}

public extension DependencyValues {
    var compositionClient: CompositionClient {
        get { self[CompositionClient.self] }
        set { self[CompositionClient.self] = newValue }
    }
}
