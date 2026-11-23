import SwiftUI
import Models
import DesignSystem

/// 문구 입력 후 같은 9:16 캔버스에서 위치·크기·회전을 정하는 자막 편집기.
struct LabelEditorView: View {
    let clip: Clip
    let rotation: ClipRotation
    /// 클립의 크롭 프레이밍(줌/이동) — 캔버스를 출력과 동일하게(WYSIWYG) 그리기 위해 받는다.
    let transform: ClipTransform
    let onCommit: (ClipLabel) -> Void
    let onCancel: () -> Void

    @State private var label: ClipLabel
    @State private var step: Step = .text
    /// 드래그 진행 중 여부 — 정렬 가이드 표시 조건.
    @State private var isDragging = false
    /// 정규화 중심(0…1). 배치의 단일 출처 — 저장 모델 `ClipLabel.position` 과 같은 좌표계다.
    @State private var anchorCenter = CGPoint(x: 0.5, y: 0.5)
    /// 드래그 시작 시점의 중심(기준점).
    @State private var dragBaseCenter = CGPoint(x: 0.5, y: 0.5)
    /// 두 손가락 제스처 진행 중 여부 + 시작 시점 기준값.
    @State private var isTransforming = false
    @State private var pinchBaseFraction: CGFloat = 0
    @State private var rotateBaseRadians: CGFloat = 0
    @State private var boxSize: CGSize = .zero
    /// 글자를 실제로 래스터화해 둔 '베이크' 비율. 슬라이더 드래그 중에는 이 값으로 그린 박스를
    /// scaleEffect 로만 부드럽게 키우고, 드래그가 끝나면 현재 값으로 베이크해 선명하게 다시 그린다.
    ///
    /// 담는 값은 **맞춤 결과**(`ClipLabel.renderedSizeFraction`)이지 사용자 의도(`sizeFraction`)가
    /// 아니다 — 이름이 `ClipLabel.renderedSizeFraction` 과 겹치면 둘을 구별할 수 없어 `baked` 로 둔다.
    @State private var bakedSizeFraction: CGFloat
    @State private var didInit = false
    @State private var showVGuide = false
    @State private var showHGuide = false
    @FocusState private var focused: Bool
    @State private var keyboard = KeyboardObserver()
    /// 커밋/취소로 화면이 닫히는 중인지. 닫히는 동안의 키보드 하강이 스텝 자동 전환을 일으키면 안 된다.
    @State private var isClosing = false

    private enum Step { case text, style }

    init(
        clip: Clip,
        rotation: ClipRotation,
        transform: ClipTransform = .fill,
        initialLabel: ClipLabel,
        onCommit: @escaping (ClipLabel) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.clip = clip
        self.rotation = rotation
        self.transform = transform
        self.onCommit = onCommit
        self.onCancel = onCancel
        _label = State(initialValue: initialLabel)
        _bakedSizeFraction = State(initialValue: initialLabel.renderedSizeFraction)
    }

    var body: some View {
        ClipEditorWorkspace(title: step == .text ? "장면 자막" : "자막 배치") {
            canvas
                .contentShape(Rectangle())
                .onTapGesture { backgroundTapped() }
        } controls: {
            if step == .text { textControls } else { styleControls }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("뒤로", systemImage: "chevron.backward") {
                    if step == .text { cancel() } else { goToText() }
                }
            }
        }
        .onAppear { keyboard.start() }
        .onDisappear { keyboard.stop() }
        .onChange(of: label.text) { _, _ in bakedSizeFraction = label.renderedSizeFraction }
        .onChange(of: keyboard.height) { old, height in
            guard old > 0, height == 0, step == .text, !isClosing else { return }
            goToStyle()
        }
    }

    private var canvas: some View {
        ChalNaCanvas { box in
            clipContent(box: box)
        } overlay: { box in
            ZStack {
                AutoLabelsOverlay(box: box, capturedAt: clip.capturedAt)
                labelLayer(box: box)
            }
            .onAppear { reflow(to: box) }
            .onChange(of: box) { _, newBox in reflow(to: newBox) }
        }
    }

    /// 클립을 출력과 동일한 센터 크롭 프레이밍(ClipFraming SSOT)으로 배치.
    @ViewBuilder
    private func clipContent(box: CGSize) -> some View {
        let render = CGSize(width: 1080, height: 1920)
        let rrect = ClipFraming.resolvedRect(
            display: clip.displaySize ?? CGSize(width: 9, height: 16),
            rotation: rotation, render: render, transform: transform
        )
        let factor = box.width / render.width
        RotatableContent(rotation: rotation) {
            clip.thumbnailView(contentMode: .fill)
        }
        .frame(width: rrect.width * factor, height: rrect.height * factor)
        .position(x: rrect.midX * factor, y: rrect.midY * factor)
    }

    // MARK: - Label layer

    private func labelLayer(box: CGSize) -> some View {
        let fontPx = bakedSizeFraction * box.height
        let scale = bakedSizeFraction > 0 ? label.renderedSizeFraction / bakedSizeFraction : 1
        return ZStack(alignment: .topLeading) {
            Color.clear.frame(width: box.width, height: box.height)
            if step == .style && isDragging { alignmentGuides(box: box) }
            if label.isVisible || step == .style {
                ClipLabelText(label: label, fontPx: fontPx, placeholder: !label.isVisible, selected: step == .style)
                    .scaleEffect(scale)
                    .contentShape(Rectangle())
                    .onTapGesture { goToText() }
                    .gesture(dragGesture(box: box), including: step == .style ? .all : .none)
                    .simultaneousGesture(magnifyAndRotateGesture, including: step == .style ? .all : .none)
                    .position(x: anchorCenter.x * box.width, y: anchorCenter.y * box.height)
            }
        }
        .frame(width: box.width, height: box.height)
    }

    @ViewBuilder
    private func alignmentGuides(box: CGSize) -> some View {
        if showVGuide {
            Rectangle().fill(ChalNaColor.accent.opacity(0.7))
                .frame(width: 1, height: box.height)
                .offset(x: box.width / 2 - 0.5, y: 0)
        }
        if showHGuide {
            Rectangle().fill(ChalNaColor.accent.opacity(0.7))
                .frame(width: box.width, height: 1)
                .offset(x: 0, y: box.height / 2 - 0.5)
        }
    }

    private var textControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("자막 문구").font(ChalNaTypography.label).foregroundStyle(ChalNaColor.textSecondary)
            TextField("자막 입력", text: $label.text)
                .textFieldStyle(.plain)
                .font(ChalNaTypography.body)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(ChalNaColor.surface, in: RoundedRectangle(cornerRadius: ChalNaRadius.sm))
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { goToStyle() }
            Button("배치와 스타일") { goToStyle() }
                .buttonStyle(.chalNa(.primary, size: .md, fillWidth: true))
                .padding(.top, 8)
        }
    }

    private var styleControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("자막을 끌어 위치를 정해요.")
                .font(ChalNaTypography.caption)
                .foregroundStyle(ChalNaColor.textSecondary)
                .frame(maxWidth: .infinity)
            HStack {
                Text("크기").font(ChalNaTypography.label)
                ChalNaSlider(value: Binding(get: { Double(label.sizeFraction) }, set: { label.sizeFraction = CGFloat($0) }),
                             range: Double(ClipLabel.minSizeFraction)...Double(ClipLabel.maxSizeFraction),
                             step: nil, onEditingChanged: { editing in
                                 if !editing { bakedSizeFraction = label.renderedSizeFraction }
                             })
            }
            Toggle("흰 배경", isOn: $label.hasBackground)
                .font(ChalNaTypography.label)
                .tint(ChalNaColor.accent)
            Button("자막 적용") { commit() }
                .buttonStyle(.chalNa(.primary, size: .md, fillWidth: true))
        }
    }

    // MARK: - Gestures / state transitions

    private func dragGesture(box: CGSize) -> some Gesture {
        // minimumDistance 16: 같은 요소에 탭(→ 문구 스텝)과 드래그(위치 조정)가 함께 걸려 있어
        // 구분이 필요하다. 짧은 제스처가 위치 조정으로 오인되는 것을 줄인다.
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragBaseCenter = anchorCenter
                }
                applyDrag(translation: value.translation, box: box)
            }
            .onEnded { _ in
                isDragging = false
                showVGuide = false
                showHGuide = false
            }
    }

    /// 드래그 결과 중심에 중심 스냅 + 0…1 clamp 적용.
    /// 중심을 직접 옮기므로 **기울기와 무관**하다(회전된 박스의 코너를 환산할 필요가 없다).
    private func applyDrag(translation: CGSize, box: CGSize) {
        guard box.width > 0, box.height > 0 else { return }
        var center = CGPoint(x: dragBaseCenter.x + translation.width / box.width,
                             y: dragBaseCenter.y + translation.height / box.height)
        center.x = min(max(center.x, 0), 1)
        center.y = min(max(center.y, 0), 1)
        let eps: CGFloat = 0.02
        showVGuide = abs(center.x - 0.5) < eps
        showHGuide = abs(center.y - 0.5) < eps
        if showVGuide { center.x = 0.5 }
        if showHGuide { center.y = 0.5 }
        anchorCenter = center
    }

    /// 두 손가락: 확대/축소(크기) + 기울기(회전)를 동시에. iOS 18 API(`MagnifyGesture`/`RotateGesture`).
    /// 크기는 슬라이더와 **같은 `sizeFraction`** 을 공유하므로 두 컨트롤이 자동으로 동기화된다.
    /// 중심(`anchorCenter`)은 건드리지 않으므로 확대·회전이 라벨을 이동시키지 않는다.
    private var magnifyAndRotateGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .simultaneously(with: RotateGesture(minimumAngleDelta: .degrees(1)))
            .onChanged { value in
                if !isTransforming {
                    isTransforming = true
                    pinchBaseFraction = label.clampedSizeFraction
                    rotateBaseRadians = label.clampedRotationRadians
                }
                if let magnification = value.first?.magnification {
                    let proposed = pinchBaseFraction * magnification
                    label.sizeFraction = min(max(proposed, ClipLabel.minSizeFraction),
                                             ClipLabel.maxSizeFraction)
                }
                if let rotation = value.second?.rotation {
                    let proposed = rotateBaseRadians + CGFloat(rotation.radians)
                    let clamped = min(max(proposed, -ClipLabel.rotationLimit), ClipLabel.rotationLimit)
                    // 0° 스냅 — 위치 드래그의 중심 스냅(eps 0.02)과 같은 패턴.
                    label.rotationRadians = abs(clamped) < ClipLabel.rotationSnapRadians ? 0 : clamped
                }
            }
            .onEnded { _ in
                isTransforming = false
                // 제스처 종료 시 현재 크기로 베이크 → scaleEffect=1 로 글자를 선명하게 재렌더
                // (크기 슬라이더의 onEditingChanged 와 같은 규칙).
                bakedSizeFraction = label.renderedSizeFraction
            }
    }

    private func goToStyle() {
        focused = false
        step = .style
    }

    private func goToText() {
        step = .text
        focused = true
    }

    /// 라벨 외 영역 탭 → 키보드만 내린다.
    /// `.text` 에서는 그 하강이 `onChange(of: keyboard.height)` 를 통해 `.style` 자동 전환으로
    /// 이어진다 — 즉 이 함수는 더 이상 "스텝 유지"를 뜻하지 않는다. `.style` 에서는 할 일이 없다.
    private func backgroundTapped() {
        if step == .text { focused = false }
    }

    /// 화면을 닫는 두 경로. 닫히는 동안의 키보드 하강이 자동 전환을 일으키지 않도록 먼저 표시한다.
    private func cancel() {
        isClosing = true
        onCancel()
    }

    private func commit() {
        isClosing = true
        onCommit(committedLabel())
    }

    // MARK: - Init / commit

    /// box(가용 영역) 확정에 맞춰 배치를 초기화한다.
    ///
    /// 배치 단일 출처가 **정규화 중심**이라 box 크기가 바뀌어도 재산출할 것이 없다 —
    /// 좌상단 코너를 저장하던 시절에는 box 마다 코너를 다시 계산해야 했다.
    private func reflow(to newBox: CGSize) {
        guard newBox.width > 0, newBox.height > 0 else { return }
        boxSize = newBox
        guard !didInit else { return }
        anchorCenter = label.position
        didInit = true
    }

    /// 저장용 라벨: 배치 단일 출처가 저장 좌표계(정규화 중심)와 같아 역산이 없다.
    private func committedLabel() -> ClipLabel {
        var result = label
        if boxSize.width > 0, boxSize.height > 0 {
            result.position = anchorCenter
        }
        return result
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

#Preview("LabelEditor · 상한 초과 시도") {
    LabelEditorView(
        clip: SampleData.jejuTimeline[0], rotation: .r0,
        initialLabel: ClipLabel(text: "제주 바다"),
        onCommit: { _ in }, onCancel: {}
    )
    .dynamicTypeSize(.accessibility5)
}
