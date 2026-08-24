import SwiftUI
import Models
import DesignSystem

/// 전체화면 라벨 에디터. 사진은 상단 고정·최대 크기로 두고, 그 위에서 라벨을 배치한다.
///
/// **2스텝 플로우** (`Step`):
/// - `.text`  : 키보드 ↑. 인라인 TextField 로 문구만 입력한다. 라벨은 가시영역(상단바~키보드)
///              높이 정중앙으로 띄운다. 하단 컨트롤 없음. `[다음]` 은 **키보드 바로 위
///              (accessory)** 에 있고, `[다음]` 을 누르지 않고 **키보드를 내려도** `.style` 로
///              자동 전환된다 — 트리거는 "키보드 높이가 0 이 되었다" 하나뿐이다.
/// - `.style` : 키보드 ↓. 라벨을 드래그로 자유 배치(중심 정렬 가이드 + 스냅)하고,
///              하단에서 배경 ON/OFF · 크기를 정한다. `[‹]`/라벨 탭 → `.text`, `[저장]` → 커밋.
///
/// 진입은 기존 라벨 재편집이어도 **항상 `.text` 부터**다. 문구를 비운 채 저장하면
/// `ClipLabel.isVisible == false` 로 라벨 없음이 되며, 이것이 라벨을 지우는 유일한 경로다
/// (그래서 `[다음]` 을 비활성화하지 않는다).
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
    @State private var step: Step = .text
    /// 드래그 진행 중 여부 — 정렬 가이드 표시 조건.
    @State private var isDragging = false
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
        .safeAreaInset(edge: .bottom) { bottomControls }
        // 라벨 외 영역 탭 → `.text` 에서는 키보드를 내린다(그 하강이 `.style` 자동 전환을 일으킨다).
        // 라벨·슬라이더는 각자 제스처가 우선.
        .contentShape(Rectangle())
        .onTapGesture { backgroundTapped() }
        .onAppear { keyboard.start() }
        .onDisappear { keyboard.stop() }
        // 키보드가 내려갔다는 **사실 하나만** 자동 전환 트리거로 쓴다. 가드 3개가 필요하다:
        //  ① step == .text — goToStyle() 이 focused=false 로 키보드를 내리므로, `[다음]` 탭 →
        //     전환 → 하강 → 다시 전환 시도가 되는 이중 발화를 막는다.
        //  ② !isClosing    — onCancel/onCommit 으로 화면이 닫힐 때도 키보드가 내려간다.
        //     사라지는 중에 스텝을 바꾸지 않는다.
        //  ③ didInit       — box 확정(=진입) 전 프레임에서 튀지 않게 한다.
        // `[‹]` 복귀는 안전하다: 복귀 시점 height 는 이미 0 이라 onChange 가 발화하지 않고,
        // goToText() 의 focused=true 로 0 → 실제 높이로 **올라가는** 변화만 관측된다.
        .onChange(of: keyboard.height) { _, newHeight in
            guard newHeight == 0, step == .text, !isClosing, didInit else { return }
            step = .style
        }
    }

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        switch step {
        case .text:
            // `[다음]` 은 키보드 바로 위(accessory)로 옮겼다 — 문구 입력 중 시선·엄지 이동을 줄인다.
            // 문자열("다음")은 그대로 유지한다: `LabelEditorUITests` 가 `app.buttons["다음"]` 으로 찾는다.
            ChalNaNavBar(
                title: "라벨",
                leading: .close(action: cancel),
                showsDivider: true
            )
        case .style:
            ChalNaNavBar(
                title: "라벨",
                leading: .back { goToText() },
                trailing: .text("저장") { commit() },
                showsDivider: true
            )
        }
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
        let floatDeltaY = displayCornerY(box: box, boxTopGlobalY: boxTopGlobalY, padded: padded) - anchorCorner.y

        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: box.width, height: box.height)

            if step == .style && isDragging {
                alignmentGuides(box: box)
            }

            // fontPx 는 베이크 크기(선명 렌더), padded 는 true 크기(드래그/위치 계산용)로 분리해 전달.
            labelContent(fontPx: renderedFontPx, padded: padded, box: box)
                .scaleEffect(liveScale, anchor: .topLeading)
                .offset(y: floatDeltaY)
                .animation(ChalNaMotion.standard, value: floatDeltaY)
                .offset(x: anchorCorner.x, y: anchorCorner.y)
        }
        .frame(width: box.width, height: box.height)
    }

    /// 표시용 코너 Y. `.text` 스텝에서는 가시영역(상단바~키보드) 높이의 정중앙으로 올린다.
    private func displayCornerY(box: CGSize, boxTopGlobalY: CGFloat, padded: CGSize) -> CGFloat {
        guard step == .text, keyboard.height > 0 else { return anchorCorner.y }
        let visibleCenterLocalY = (keyboard.topY - boxTopGlobalY) / 2   // 박스 상단=상단바 아래 기준
        return visibleCenterLocalY - padded.height / 2
    }

    @ViewBuilder
    private func labelContent(fontPx: CGFloat, padded: CGSize, box: CGSize) -> some View {
        switch step {
        case .text:
            inlineEditor(fontPx: fontPx)
        case .style:
            let isEmpty = label.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ClipLabelText(label: label, fontPx: fontPx, placeholder: isEmpty)
                .overlay(selectionFrame)
                .contentShape(Rectangle())
                .onTapGesture { goToText() }
                .gesture(dragGesture(box: box, padded: padded))
        }
    }

    /// 편집 상태: 같은 박스 스타일의 인라인 TextField.
    ///
    /// **다크 토큰 적용 예외(폰트만).** 라벨 박스는 영상 출력(`CATextLayer`)과 픽셀 일치해야
    /// 하므로 Dynamic Type 을 따르는 역할 토큰이 아니라 `.font(.system(size: fontPx, ...))` 를
    /// 직접 쓴다 — `scripts/design-lint.sh` 규칙 1 예외에 이 파일이 등록돼 있다.
    /// 색은 리터럴을 두지 않고 `ClipLabelBoxPalette`(ClipLabelText.swift)를 호출한다.
    private func inlineEditor(fontPx: CGFloat) -> some View {
        let textWidth = LabelAnchorMath.textSize(text: label.text, fontPx: fontPx).width
        let isEmpty = label.text.isEmpty
        return TextField("", text: $label.text)
            // 역할 토큰(krBody 삭제됨) 대신 직접 시스템 폰트 — 위 함수 doc 참고: 영상 출력과 픽셀 일치 필요.
            .font(.system(size: fontPx, weight: .light))
            .tracking(ClipLabel.BoxStyle.letterSpacing(for: fontPx))
            .foregroundColor(ClipLabelBoxPalette.foreground(
                hasBackground: label.hasBackground, placeholder: false
            ))
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
                        .foregroundColor(ClipLabelBoxPalette.foreground(
                            hasBackground: label.hasBackground, placeholder: true
                        ))
                        .lineLimit(1)
                        .fixedSize()
                        .allowsHitTesting(false)
                }
            }
            .focused($focused)
            .submitLabel(.done)
            .onSubmit { focused = false }
            .boxSubtitleStyle(fontPx: fontPx, hasBackground: label.hasBackground)
    }

    // `labelContent` 가 `.style` 케이스에서만 이 오버레이를 붙이므로 step 분기가 필요 없다.
    private var selectionFrame: some View {
        Rectangle()
            .strokeBorder(ChalNaColor.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .padding(-3)
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

    // MARK: - Bottom controls

    @ViewBuilder
    private var bottomControls: some View {
        switch step {
        case .text:  nextAccessoryBar
        case .style: styleControls
        }
    }

    /// 문구 스텝의 `[다음]` — 키보드 바로 위에 뜬다.
    ///
    /// **왜 SwiftUI 표준 경로가 아닌가(실측 근거).** `ToolbarItemGroup(placement: .keyboard)` 를
    /// 먼저 시도했고, 커버 콘텐츠 루트와 포커스된 `TextField` 양쪽에 각각 붙여 확인했다 —
    /// 두 경우 모두 **아무것도 렌더되지 않았다**(XCUITest 요소 덤프: `toolbars=0`, `다음` 버튼 부재).
    /// 이 화면은 `NavigationStack` 없는 `fullScreenCover` 콘텐츠라 toolbar 호스트가 없다.
    /// 그렇다고 `UIViewRepresentable`(inputAccessoryView) 로 내려가지는 않는다 — 이미 있는
    /// `KeyboardObserver.height` 로 직접 띄우면 SwiftUI 전용 규약을 지키면서 바 스타일까지
    /// 토큰으로 잡을 수 있다(시스템 크롬은 토큰을 못 쓴다).
    private var nextAccessoryBar: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button("다음") { goToStyle() }
                .font(ChalNaTypography.headline)
                .foregroundColor(ChalNaColor.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .background(ChalNaColor.surfaceRaised)
        .overlay(alignment: .top) {
            Rectangle().fill(ChalNaColor.border).frame(height: 1)
        }
        // 본문이 `.ignoresSafeArea(.keyboard)` 라 이 바도 키보드에 밀리지 않는다 —
        // 관찰한 키보드 높이만큼 직접 올린다.
        .offset(y: -keyboard.height)
        .animation(ChalNaMotion.standard, value: keyboard.height)
    }

    @ViewBuilder
    private var styleControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("배경")
                    .font(ChalNaTypography.label)
                    .foregroundColor(ChalNaColor.textSecondary)
                Spacer(minLength: 0)
                Toggle("", isOn: $label.hasBackground)
                    .labelsHidden()
                    .tint(ChalNaColor.accentFill)
            }

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
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(ChalNaColor.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(ChalNaColor.border).frame(height: 1)
        }
    }

    // MARK: - Gestures / state transitions

    private func dragGesture(box: CGSize, padded: CGSize) -> some Gesture {
        // minimumDistance 16: 같은 요소에 탭(→ 문구 스텝)과 드래그(위치 조정)가 함께 걸려 있어
        // 구분이 필요하다. 짧은 제스처가 위치 조정으로 오인되는 것을 줄인다.
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragBaseCorner = anchorCorner
                }
                applyDrag(
                    proposed: CGPoint(x: dragBaseCorner.x + value.translation.width,
                                      y: dragBaseCorner.y + value.translation.height),
                    box: box, padded: padded
                )
            }
            .onEnded { _ in
                isDragging = false
                showVGuide = false
                showHGuide = false
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

    /// box(가용 영역) 확정·변경에 맞춰 배치를 갱신한다.
    /// - 최초 1회: 저장된 position(center) → anchorCorner 로 변환(진입은 항상 문구 스텝에서 시작).
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
            // 진입은 항상 문구 스텝(`step` 기본값 `.text`)이다 — 기존 라벨 재편집도 마찬가지.
            focused = true
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
