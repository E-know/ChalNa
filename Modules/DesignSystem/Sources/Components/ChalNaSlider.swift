import SwiftUI

/// 다크용 슬라이더. LabelEditor 라벨 크기 조절에 쓴다.
///
/// 시스템 `Slider` 를 감싸고 tint 만 지정한다 — 트랙·노브를 직접 그리면
/// 접근성(조절 제스처·VoiceOver adjustable)을 다시 구현해야 하는데
/// 그만한 시각적 이득이 없다.
public struct ChalNaSlider: View {
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let step: Double?
    private let onEditingChanged: (Bool) -> Void

    public init(
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...1,
        step: Double? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        Group {
            if let step {
                Slider(value: $value, in: range, step: step, onEditingChanged: onEditingChanged)
            } else {
                Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
            }
        }
        .tint(ChalNaColor.accentFill)
    }
}
