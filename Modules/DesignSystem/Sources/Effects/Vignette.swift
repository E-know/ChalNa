import SwiftUI

/// 외곽 어둡게 내리는 비네트 오버레이. 크림 배경 위에서 photo-like 질감 연출.
public struct Vignette: View {
    public var intensity: Double

    public init(intensity: Double = 0.10) {
        self.intensity = intensity
    }

    public var body: some View {
        RadialGradient(
            colors: [.clear, MomentsColor.ink.opacity(intensity)],
            center: .center,
            startRadius: 0,
            endRadius: 520
        )
        .blendMode(.multiply)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

public extension View {
    func momentsVignette(_ intensity: Double = 0.10) -> some View {
        self.overlay(Vignette(intensity: intensity))
    }
}
