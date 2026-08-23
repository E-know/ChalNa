import SwiftUI
import Models
import DesignSystem

/// 전체화면 라벨 에디터. 사진은 상단 고정·최대 크기로 두고, 그 위에서 라벨을 배치한다.
///
/// 상태 머신(`Phase`):
/// - `.idle`     : 사진 위 저장된 위치에 라벨 표시. 탭→`.editing`, 드래그→`.adjusting`.
/// - `.editing`  : 키보드 ↑. 라벨을 가시영역(상단바~키보드) **높이 정중앙**으로 띄워 입력. 크기 슬라이더는 키보드 위로.
///                 라벨 외 탭/완료 시 원래 위치로 복귀.
/// - `.adjusting`: 키보드 ↓. 라벨을 드래그로 자유 배치(중심 정렬 가이드 + 스냅). "완료"/바깥 탭으로 종료.
///
/// 배치는 box-local **좌상단 코너 `anchorCorner`(point)** 를 단일 출처로 삼고(요구: leading/top 고정·우하 확장),
/// 저장 모델 `ClipLabel.position`(중심)은 커밋 시 코너에서 역산한다 → 합성/미리보기와 WYSIWYG 유지.
struct LabelEditorView: View {
    let clip: Clip
    let rotation: ClipRotation
    /// 클립의 크롭 프레이밍(줌/이동) — 캔버스를 출력과 동일하게(WYSIWYG) 그리기 위해 받는다.
    let transform: ClipTransform
    let onCommit: (ClipLabel) -> Void
    let onCancel: () -> Void

    @State private var label: ClipLabel
    @State private var phase: Phase = .idle
    /// box-local 좌상단 코너(point). 배치의 단일 출처.
    @State private var anchorCorner: CGPoint = .zero
    /// 드래그 시작 시점의 코너(기준점).
    @State private var dragBaseCorner: CGPoint = .zero
    @State private var boxSize: CGSize = .zero
    /// 글자를 실제로 래스터화해 둔 '베이크' 크기 비율. 슬라이더 드래그 중에는 이 값으로 그린 박스를
    /// scaleEffect 로만 부드럽게 키우고, 드래그가 끝나면 현재 값으로 베이크해 선명하게 다시 그린다.
    @State private var renderedSizeFraction: CGFloat
    @State private var didInit = false
    @State private var showVGuide = false
    @State private var showHGuide = false
    @FocusState private var focused: Bool
    @State private var keyboard = KeyboardObserver()

    private enum Phase { case idle, editing, adjusting }

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
        _renderedSizeFraction = State(initialValue: initialLabel.clampedSizeFraction)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
        }
        // 본문은 키보드에 밀리거나 리사이즈되지 않아야 한다.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .chalNaScreen()
        // 슬라이더는 실제 높이만 차지한다. 기존 84pt 고정 예약(Color.clear)은
        // 키보드·세이프에어리어 조합에 따라 캔버스를 과하게 줄였다.
        .safeAreaInset(edge: .bottom) { sizeControls }
        // 라벨 외 영역 탭 → 키보드 내림 / ADJUST 종료. 라벨·슬라이더는 각자 제스처가 우선.
        .contentShape(Rectangle())
        .onTapGesture { backgroundTapped() }
        .onChange(of: focused) { _, isFocused in
            if !isFocused, phase == .editing { phase = .idle }
        }
        .onAppear { keyboard.start() }
        .onDisappear { keyboard.stop() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ChalNaNavBar(
            title: "라벨",
            leading: .close(action: onCancel),
            trailing: .text("저장") { onCommit(committedLabel()) },
            showsDivider: true
        )
    }

    // MARK: - Canvas (사진 상단 고정 + 라벨 오버레이)

    private var canvas: some View {
        GeometryReader { proxy in
            // ChalNaCanvas 는 내부적으로 박스를 .center 정렬한다(공유 컴포넌트의 의도된 기본값 —
            // ClipAdjustView 등 다른 소비자는 그 정렬에 의존한다). 이 화면만 boxTopGlobalY 가
            // 박스의 실제 상단과 일치해야 하므로(displayCornerY·dragGesture 의 전제),
            // 박스 크기를 미리 계산해 ChalNaCanvas 를 그 크기로 딱 맞게 제한한 뒤(슬랙 0 →
            // 정렬 무관), 바깥에서 직접 상단 정렬한다 — 공유 컴포넌트의 기본 정렬은 바꾸지 않는다.
            let box = LabelBoxGeometry.fittedBox(aspect: ChalNaCanvasGeometry.defaultAspect, in: proxy.size)
            let boxTopGlobalY = proxy.frame(in: .global).minY
            ChalNaCanvas { box in
                clipContent(box: box)
            } overlay: { box in
                ZStack(alignment: .top) {
                    AutoLabelsOverlay(box: box, capturedAt: clip.capturedAt)
                        .frame(width: box.width, height: box.height)
                        .allowsHitTesting(false)
                    labelLayer(box: box, boxTopGlobalY: boxTopGlobalY)
                }
                .onAppear { reflow(from: .zero, to: box) }
                .onChange(of: box) { oldBox, newBox in reflow(from: oldBox, to: newBox) }
            }
            .frame(width: box.width, height: box.height)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
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

    @ViewBuilder
    private func labelLayer(box: CGSize, boxTopGlobalY: CGFloat) -> some View {
        // 위치/드래그/플로팅은 '최종 표시 크기'(true fontPx) 기준으로 계산한다.
        let fontPx = label.clampedSizeFraction * box.height
        let padded = LabelAnchorMath.paddedBoxSize(text: label.text, fontPx: fontPx)
        // 글자는 '베이크' 크기로만 래스터화하고, 슬라이더 드래그 중 차이는 scaleEffect 로 부드럽게 메운다.
        // (매 프레임 폰트 재래스터화/박스 ceil 반올림으로 생기는 '뚝뚝 끊김'을 GPU 기하 변환으로 대체)
        let renderedFontPx = renderedSizeFraction * box.height
        let liveScale = renderedSizeFraction > 0 ? label.clampedSizeFraction / renderedSizeFraction : 1
        // 편집 진입 시 가시영역 중앙으로 올리는 '플로팅' 델타. 이 델타만 애니메이션하고,
        // 위치(anchorCorner) 오프셋은 애니메이션 밖에 둬 드래그가 손가락을 1:1 로 따라가게 한다.
        // (.adjusting 중에는 플로팅 애니메이션도 꺼서 드래그가 즉시 반영되도록 한다.)
        let floatDeltaY = displayCornerY(box: box, boxTopGlobalY: boxTopGlobalY, padded: padded) - anchorCorner.y

        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: box.width, height: box.height)

            if phase == .adjusting {
                alignmentGuides(box: box)
            }

            // fontPx 는 베이크 크기(선명 렌더), padded 는 true 크기(드래그/위치 계산용)로 분리해 전달.
            labelContent(fontPx: renderedFontPx, padded: padded, box: box, boxTopGlobalY: boxTopGlobalY)
                .scaleEffect(liveScale, anchor: .topLeading)
                .offset(y: floatDeltaY)
                .animation(phase == .adjusting ? nil : ChalNaMotion.standard, value: floatDeltaY)
                .offset(x: anchorCorner.x, y: anchorCorner.y)
        }
        .frame(width: box.width, height: box.height)
    }

    /// 표시용 코너 Y. EDIT 에서는 가시영역(상단바~키보드) 높이의 정중앙으로 올린다.
    private func displayCornerY(box: CGSize, boxTopGlobalY: CGFloat, padded: CGSize) -> CGFloat {
        guard phase == .editing, keyboard.height > 0 else { return anchorCorner.y }
        let visibleCenterLocalY = (keyboard.topY - boxTopGlobalY) / 2   // 박스 상단=상단바 아래 기준
        return visibleCenterLocalY - padded.height / 2
    }

    @ViewBuilder
    private func labelContent(fontPx: CGFloat, padded: CGSize, box: CGSize, boxTopGlobalY: CGFloat) -> some View {
        if phase == .editing {
            inlineEditor(fontPx: fontPx)
                // 편집 중에도 라벨을 드래그하면 키보드를 내리고 위치 조정으로 전환(요구 3).
                .highPriorityGesture(dragGesture(box: box, padded: padded, boxTopGlobalY: boxTopGlobalY))
        } else {
            let isEmpty = label.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ClipLabelText(label: label, fontPx: fontPx, placeholder: isEmpty)
                .overlay(selectionFrame)
                .contentShape(Rectangle())
                .onTapGesture { startEditing() }
                .gesture(dragGesture(box: box, padded: padded, boxTopGlobalY: boxTopGlobalY))
        }
    }

    /// 편집 상태: 같은 박스 스타일의 인라인 TextField.
    ///
    /// **다크 토큰 적용 예외.** 라벨 박스(흰 배경 · 검은 글자)는 영상 출력과
    /// 픽셀 일치해야 하므로 UI 테마와 무관하다. `ClipLabel.BoxStyle` 이 SSOT 다.
    /// 여기서 `.black` 리터럴을 쓰는 것은 의도된 것이며
    /// `scripts/design-lint.sh` 의 검정 하드코딩 규칙 예외 경로에 이 파일이 등록돼 있다.
    private func inlineEditor(fontPx: CGFloat) -> some View {
        let textWidth = LabelAnchorMath.textSize(text: label.text, fontPx: fontPx).width
        let isEmpty = label.text.isEmpty
        return TextField("", text: $label.text)
            // 역할 토큰(krBody 삭제됨) 대신 직접 시스템 폰트 — 위 함수 doc 참고: 영상 출력과 픽셀 일치 필요.
            .font(.system(size: fontPx, weight: .light))
            .tracking(ClipLabel.BoxStyle.letterSpacing(for: fontPx))
            .foregroundColor(.black)
            .tint(ChalNaColor.accentFill)
            .multilineTextAlignment(.leading)
            .lineLimit(1)
            .frame(width: textWidth + 4, alignment: .leading)   // +4: 커서 표시 여유
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .leading) {
                if isEmpty {
                    Text("자막 입력")
                        .font(.system(size: fontPx, weight: .light))
                        .tracking(ClipLabel.BoxStyle.letterSpacing(for: fontPx))
                        .foregroundColor(.black.opacity(0.5))
                        .lineLimit(1)
                        .fixedSize()
                        .allowsHitTesting(false)
                }
            }
            .focused($focused)
            .submitLabel(.done)
            .onSubmit { focused = false }
            .boxSubtitleStyle(fontPx: fontPx)
    }

    private var selectionFrame: some View {
        Rectangle()
            .strokeBorder(ChalNaColor.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .padding(-3)
            .opacity(phase == .adjusting ? 1 : 0)
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

    // MARK: - Size controls

    private var sizeControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("크기")
                .font(ChalNaTypography.label)
                .foregroundColor(ChalNaColor.textSecondary)
            ChalNaSlider(
                // ChalNaSlider 는 Binding<Double> — sizeFraction(CGFloat)을 브리징한다.
                value: Binding(
                    get: { Double(label.sizeFraction) },
                    set: { label.sizeFraction = CGFloat($0) }
                ),
                range: Double(ClipLabel.minSizeFraction)...Double(ClipLabel.maxSizeFraction),
                step: nil,
                onEditingChanged: { editing in
                    // 드래그 종료 시 현재 크기로 베이크 → scaleEffect=1 로 글자를 선명하게 재렌더.
                    if !editing { renderedSizeFraction = label.clampedSizeFraction }
                }
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(ChalNaColor.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(ChalNaColor.border).frame(height: 1)
        }
        // EDIT 중에는 키보드 위로 띄운다.
        .padding(.bottom, phase == .editing ? keyboard.height : 0)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(ChalNaMotion.standard, value: keyboard.height)
        .animation(ChalNaMotion.standard, value: phase)
    }

    // MARK: - Gestures / state transitions

    private func dragGesture(box: CGSize, padded: CGSize, boxTopGlobalY: CGFloat) -> some Gesture {
        // minimumDistance 를 다소 크게(16) 둬, 편집 중 캐럿 탭/짧은 제스처가 위치조정으로 오인되는 것을 줄인다.
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .onChanged { value in
                if phase != .adjusting {
                    // 위치 조정 모드 진입: 키보드 내림. 현재 보이는 코너에서 이어서 끌리도록 기준점 설정.
                    let startY = displayCornerY(box: box, boxTopGlobalY: boxTopGlobalY, padded: padded)
                    dragBaseCorner = CGPoint(x: anchorCorner.x, y: startY)
                    let wasEditing = (phase == .editing)
                    phase = .adjusting
                    if wasEditing { focused = false }
                }
                let proposed = CGPoint(
                    x: dragBaseCorner.x + value.translation.width,
                    y: dragBaseCorner.y + value.translation.height
                )
                applyDrag(proposed: proposed, box: box, padded: padded)
            }
            .onEnded { _ in
                // 드래그가 끝나면 위치조정 모드 종료 → IDLE 복귀(위치는 anchorCorner 에 이미 반영됨).
                endAdjusting()
            }
    }

    /// 드래그 결과 코너에 중심 스냅 + 0…1 clamp 적용.
    private func applyDrag(proposed: CGPoint, box: CGSize, padded: CGSize) {
        var center = LabelAnchorMath.center(topLeft: proposed, in: box, paddedSize: padded)
        let eps: CGFloat = 0.02
        showVGuide = abs(center.x - 0.5) < eps
        showHGuide = abs(center.y - 0.5) < eps
        if showVGuide { center.x = 0.5 }
        if showHGuide { center.y = 0.5 }
        anchorCorner = LabelAnchorMath.topLeft(center: center, in: box, paddedSize: padded)
    }

    private func startEditing() {
        phase = .editing
        focused = true
    }

    private func endAdjusting() {
        showVGuide = false
        showHGuide = false
        phase = .idle
    }

    private func backgroundTapped() {
        switch phase {
        case .editing:   focused = false           // → onChange(focused) 에서 .idle 로
        case .adjusting: endAdjusting()
        case .idle:      break
        }
    }

    // MARK: - Init / commit

    /// box(가용 영역) 확정·변경에 맞춰 배치를 갱신한다.
    /// - 최초 1회: 저장된 position(center) → anchorCorner 로 변환(+빈 라벨이면 편집 시작).
    /// - 이후 box 변경(예: 디바이스 회전으로 fittedBox 가 달라질 때): 정규화 center 를 보존하도록
    ///   anchorCorner 를 재산출 → 라벨 위치/저장값(committedLabel)이 어긋나지 않게 한다.
    private func reflow(from oldBox: CGSize, to newBox: CGSize) {
        guard newBox.width > 0, newBox.height > 0 else { return }
        boxSize = newBox
        guard didInit else {
            let fontPx = label.clampedSizeFraction * newBox.height
            let padded = LabelAnchorMath.paddedBoxSize(text: label.text, fontPx: fontPx)
            anchorCorner = LabelAnchorMath.topLeft(center: label.position, in: newBox, paddedSize: padded)
            didInit = true
            if !label.isVisible { startEditing() }   // 빈 라벨이면 바로 편집 시작
            return
        }
        guard oldBox.width > 0, oldBox.height > 0, newBox != oldBox else { return }
        let centerNorm = LabelAnchorMath.center(
            topLeft: anchorCorner, in: oldBox,
            paddedSize: LabelAnchorMath.paddedBoxSize(text: label.text, fontPx: label.clampedSizeFraction * oldBox.height)
        )
        anchorCorner = LabelAnchorMath.topLeft(
            center: centerNorm, in: newBox,
            paddedSize: LabelAnchorMath.paddedBoxSize(text: label.text, fontPx: label.clampedSizeFraction * newBox.height)
        )
    }

    /// 저장용 라벨: 현재 좌상단 코너에서 중심을 역산해 `position` 갱신.
    private func committedLabel() -> ClipLabel {
        var result = label
        if boxSize.width > 0, boxSize.height > 0 {
            let fontPx = label.clampedSizeFraction * boxSize.height
            let padded = LabelAnchorMath.paddedBoxSize(text: label.text, fontPx: fontPx)
            result.position = LabelAnchorMath.center(topLeft: anchorCorner, in: boxSize, paddedSize: padded)
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
