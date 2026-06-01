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
    @FocusState private var focused: Bool

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
        VStack(spacing: 0) {
            topBar
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
            controls
        }
        .chalNaScreen()
        .onAppear { if !label.isVisible { startEditing() } }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { isEditingText = false }
        }
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

    @ViewBuilder
    private func labelOverlay(boxSize: CGSize) -> some View {
        let fontPx = label.clampedSizeFraction * boxSize.height
        let centerX = label.position.x * boxSize.width + dragTranslation.width
        let centerY = label.position.y * boxSize.height + dragTranslation.height
        Group {
            if isEditingText {
                inlineEditor(fontPx: fontPx)
            } else {
                displayLabel(fontPx: fontPx, boxSize: boxSize)
            }
        }
        .position(x: centerX, y: centerY)
    }

    /// 표시 상태: 드래그로 위치 이동, 탭하면 같은 자리에서 인라인 편집 시작.
    private func displayLabel(fontPx: CGFloat, boxSize: CGSize) -> some View {
        let isEmpty = label.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return ClipLabelText(label: label, fontPx: fontPx, placeholder: isEmpty)
            .gesture(
                // 좌표계를 .global 로 고정 — 박스가 이동해도 로컬 좌표계가 따라 움직여 생기는 떨림 방지.
                DragGesture(coordinateSpace: .global)
                    .updating($dragTranslation) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        guard boxSize.width > 0, boxSize.height > 0 else { return }
                        let nx = (label.position.x * boxSize.width + value.translation.width) / boxSize.width
                        let ny = (label.position.y * boxSize.height + value.translation.height) / boxSize.height
                        label.position = CGPoint(x: min(max(nx, 0), 1), y: min(max(ny, 0), 1))
                    }
            )
            .onTapGesture { startEditing() }
    }

    /// 편집 상태: 같은 위치·같은 박스 스타일(흰 배경·검정 글씨·테두리)로 그리는 인라인 TextField. WYSIWYG.
    private func inlineEditor(fontPx: CGFloat) -> some View {
        TextField("자막 입력", text: $label.text)
            .font(ChalNaTypography.krBody(fontPx, weight: .light))
            .tracking(ClipLabel.BoxStyle.letterSpacing(for: fontPx))
            .foregroundColor(.black)
            .tint(ChalNaColor.coral)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .fixedSize()
            .focused($focused)
            .submitLabel(.done)
            .onSubmit { focused = false }
            .boxSubtitleStyle(fontPx: fontPx)
    }

    private func startEditing() {
        isEditingText = true
        focused = true
    }

    // MARK: - Controls

    private var controls: some View {
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
        .padding(16)
    }
}

#Preview {
    LabelEditorView(
        clip: SampleData.jejuTimeline[0],
        rotation: .r0,
        initialLabel: ClipLabel(text: "제주 바다"),
        onCommit: { _ in },
        onCancel: {}
    )
}
