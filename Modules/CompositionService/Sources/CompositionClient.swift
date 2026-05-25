import Foundation
import ComposableArchitecture
import Models

/// AVFoundationCompositionService 를 TCA @DependencyClient 로 노출한 형태.
/// ExportFeature 에서 `@Dependency(\.compositionClient)` 로 주입.
@DependencyClient
public struct CompositionClient: Sendable {
    public var export: @Sendable (
        _ clips: [Clip],
        _ rotations: [Clip.ID: ClipRotation]
    ) -> AsyncStream<ExportEvent> = { _, _ in
        AsyncStream { $0.finish() }
    }
}

extension CompositionClient: DependencyKey {
    public static let liveValue: CompositionClient = {
        let service = AVFoundationCompositionService()
        return CompositionClient(
            export: { clips, rotations in
                service.export(clips: clips, rotations: rotations)
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
