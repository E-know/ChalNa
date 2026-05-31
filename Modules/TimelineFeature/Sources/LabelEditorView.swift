import SwiftUI
import Models
import DesignSystem

/// 전체화면 라벨 에디터. 클립 이미지 위에서 라벨을 자유 드래그로 배치하고
/// 폰트·스타일·크기를 고른다. "저장" 시 편집 결과 ClipLabel 을 onCommit 으로 돌려준다.
struct LabelEditorView: View {
    let clip: Clip
    let rotation: ClipRotation
    let onCommit: (ClipLabel) -> Void
    let onCancel: () -> Void

    @State private var label: ClipLabel
    @GestureState private var dragTranslation: CGSize = .zero
    @State private var isEditingText = false

    init(
        clip: Clip,
        rotation: ClipRotation,
        initialLabel: ClipLabel,
        onCommit: @escaping (ClipLabel) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.clip = clip
        self.rotation = rotation
        self.onCommit = onCommit
        self.onCancel = onCancel
        _label = State(initialValue: initialLabel)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                canvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                controls
            }
            .chalNaScreen()

            if isEditingText {
                LabelTextInputView(
                    clip: clip,
                    initialText: label.text,
                    font: label.font,
                    onCommit: { label.text = $0; isEditingText = false },
                    onCancel: { isEditingText = false }
                )
            }
        }
        .onAppear { if !label.isVisible { isEditingText = true } }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                ChalNaIcon(.close, size: 20).foregroundColor(ChalNaColor.ink)
            }
            .chalNaHitTarget()
            .accessibilityLabel("취소")

            Spacer()
            Text("라벨")
                .font(ChalNaTypography.krSemibold(15))
                .foregroundColor(ChalNaColor.ink)
            Spacer()

            Button("저장") { onCommit(label) }
                .font(ChalNaTypography.krBody(15, weight: .semibold))
                .foregroundColor(ChalNaColor.coral)
                .chalNaHitTarget()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Canvas (드래그 캔버스)

    private var canvas: some View {
        GeometryReader { proxy in
            let aspect = LabelBoxGeometry.displayAspect(displaySize: clip.displaySize, rotation: rotation)
            let box = LabelBoxGeometry.fittedBox(aspect: aspect, in: proxy.size)
            ZStack {
                RotatableContent(rotation: rotation) {
                    clip.thumbnailView(contentMode: .fill)
                }
                .frame(width: box.width, height: box.height)
                .clipped()
                .overlay(AutoLabelsOverlay(box: box, capturedAt: clip.capturedAt))
                .overlay(labelOverlay(boxSize: box))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func labelOverlay(boxSize: CGSize) -> some View {
        let fontPx = label.clampedSizeFraction * boxSize.height
        let centerX = label.position.x * boxSize.width + dragTranslation.width
        let centerY = label.position.y * boxSize.height + dragTranslation.height
        return labelView(fontPx: fontPx)
            .position(x: centerX, y: centerY)
            .gesture(
                DragGesture()
                    .updating($dragTranslation) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        guard boxSize.width > 0, boxSize.height > 0 else { return }
                        let nx = (label.position.x * boxSize.width + value.translation.width) / boxSize.width
                        let ny = (label.position.y * boxSize.height + value.translation.height) / boxSize.height
                        label.position = CGPoint(x: min(max(nx, 0), 1), y: min(max(ny, 0), 1))
                    }
            )
            .onTapGesture { isEditingText = true }
    }

    private func labelView(fontPx: CGFloat) -> some View {
        let isEmpty = label.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return ClipLabelText(label: label, fontPx: fontPx, placeholder: isEmpty)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                segmented(title: "폰트",
                          options: LabelFont.allCases.map { ($0.displayName, $0) },
                          selection: $label.font)
                segmented(title: "글자색",
                          options: LabelColor.allCases.map { ($0.displayName, $0) },
                          selection: $label.textColor)
            }

            segmented(title: "배경",
                      options: LabelBackground.allCases.map { ($0.displayName, $0) },
                      selection: $label.background)

            VStack(alignment: .leading, spacing: 6) {
                Text("크기")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.small, weight: .medium))
                    .foregroundColor(ChalNaColor.ink)
                Slider(
                    value: $label.sizeFraction,
                    in: ClipLabel.minSizeFraction...ClipLabel.maxSizeFraction
                )
                .tint(ChalNaColor.coral)
            }
        }
        .padding(16)
    }

    private func segmented<T: Equatable>(
        title: String,
        options: [(String, T)],
        selection: Binding<T>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.small, weight: .medium))
                .foregroundColor(ChalNaColor.ink)
            HStack(spacing: 8) {
                ForEach(options.indices, id: \.self) { i in
                    let opt = options[i]
                    let isOn = selection.wrappedValue == opt.1
                    Button {
                        selection.wrappedValue = opt.1
                    } label: {
                        Text(opt.0)
                            .font(ChalNaTypography.krBody(13, weight: .medium))
                            .foregroundColor(isOn ? .white : ChalNaColor.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: ChalNaRadius.button, style: .continuous)
                                    .fill(isOn ? ChalNaColor.coral : ChalNaColor.ivory)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    LabelEditorView(
        clip: SampleData.jejuTimeline[0],
        rotation: .r0,
        initialLabel: ClipLabel(text: "제주 바다", font: .memoment, background: .black, textColor: .white),
        onCommit: { _ in },
        onCancel: {}
    )
}
