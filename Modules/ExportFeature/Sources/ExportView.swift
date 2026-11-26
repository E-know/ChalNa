import AppCore
import AVFoundation
import AVKit
import ComposableArchitecture
import DesignSystem
import Models
import SwiftUI

public struct ExportView: View {
    @Environment(EditSession.self) private var session
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var returningFromSettings = false
    @Bindable var store: StoreOf<ExportFeature>

    public init(store: StoreOf<ExportFeature> = Store(initialState: .init()) { ExportFeature() }) {
        self.store = store
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let split = ChalNaLayout.isSplit(size)
            VStack(alignment: .leading, spacing: 0) {
                switch store.phase {
                case .idle, .done:
                    if split {
                        HStack(spacing: 28) {
                            poster(width: min(size.width * 0.42, max(1, size.height - 82) * 9 / 16))
                                .frame(maxWidth: .infinity)
                            ScrollView {
                                VStack(alignment: .leading, spacing: 18) {
                                    if store.phase == .done { completionLabel }
                                    titleBlock
                                    Divider()
                                    information
                                    actions
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                            }
                            .frame(width: size.width * 0.44)
                        }
                        .padding(.horizontal, 24)
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 22) {
                                if store.phase == .done { completionLabel }
                                HStack(spacing: 16) {
                                    poster(width: min(max(1, size.width - 48) * (store.phase == .done ? 0.56 : 0.36),
                                                      max(90, size.height * (store.phase == .done ? 0.44 : 0.28)) * 9 / 16))
                                    titleBlock
                                }
                                Divider()
                                information
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                        }
                        actions.padding(.horizontal, 24).padding(.vertical, 8)
                    }
                case .exporting:
                    progressView
                case .limited, .failed:
                    failureView
                }
            }
        }
        .foregroundStyle(ChalNaColor.textPrimary)
        .chalNaScreen()
        .navigationTitle(store.phase == .done ? LocalizedStringKey("완성한 필름") : "필름 만들기")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(store.phase == .exporting || store.phase == .done)
        .toolbar {
            if store.phase == .done {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기", systemImage: "xmark") { store.send(.homeTapped) }
                        .disabled(archivePending)
                }
            }
        }
        .onAppear { if store.phase == .idle { store.send(.confirmationAppeared) } }
        .onChange(of: store.phase, initial: true) { _, phase in
            UIApplication.shared.isIdleTimerDisabled = phase == .exporting
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, returningFromSettings else { return }
            returningFromSettings = false
            store.send(.saveToPhotoLibraryTapped)
        }
        .fullScreenCover(isPresented: $store.isPlayerPresented.sending(\.playerPresentedChanged)) {
            if let url = store.exportedURL {
                NavigationStack {
                    ExportVideoPlayerCover(url: url) { store.send(.playerPresentedChanged(false)) }
                        .ignoresSafeArea()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("닫기", systemImage: "xmark") { store.send(.playerPresentedChanged(false)) }
                            }
                        }
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
    }

    private var archivePending: Bool {
        store.phase == .done && (store.archiveStatus == .idle || store.archiveStatus == .saving)
    }

    private var title: String { store.entry?.title ?? (session.title.isEmpty ? "ChalNa" : session.title) }
    private var count: Int { store.entry?.clipCount ?? session.clips.count }
    private var duration: Double { store.entry?.duration ?? session.clips.reduce(0) { $0 + $1.duration } }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: title)
                .font(store.phase == .done ? ChalNaTypography.display : ChalNaTypography.title)
                .lineLimit(3)
            if store.phase == .done {
                Text("클립 \(count)개 · \(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2))))")
                    .font(ChalNaTypography.label)
                    .foregroundStyle(ChalNaColor.textSecondary)
            } else {
                Text("클립 \(count)개 · \(duration, specifier: "%.1f")초")
                    .font(ChalNaTypography.label)
                    .foregroundStyle(ChalNaColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func poster(width: CGFloat) -> some View {
        let h = width * 16 / 9
        let cover = Group {
            if let data = store.cover, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let clip = session.clips.first {
                let size = CGSize(width: width, height: h)
                let rotation = session.rotation(for: clip.id)
                let rect = ClipFraming.resolvedRect(display: clip.displaySize ?? size, rotation: rotation,
                                                    render: size, transform: session.transform(for: clip.id))
                ZStack(alignment: .bottomTrailing) {
                    ChalNaColor.canvas
                    clip.thumbnailView()
                        .frame(width: rotation.swapsAxes ? rect.height : rect.width,
                               height: rotation.swapsAxes ? rect.width : rect.height)
                        .rotationEffect(.degrees(rotation.degrees))
                        .position(x: rect.midX, y: rect.midY)
                    VStack(alignment: .trailing, spacing: width * LabelLayout.stackGapFraction) {
                        Text(verbatim: LabelText.timeString(clip.capturedAt))
                            .font(LabelText.font(px: width * LabelLayout.timeFontFraction))
                        Text(verbatim: LabelText.dateString(clip.capturedAt))
                            .font(LabelText.font(px: width * LabelLayout.dateFontFraction))
                    }
                    .foregroundStyle(ChalNaColor.onMedia.opacity(LabelLayout.opacity))
                    .padding(.trailing, width * LabelLayout.paddingFraction)
                    .padding(.bottom, h * LabelLayout.paddingFraction)
                    let label = session.label(for: clip.id)
                    if label.isVisible {
                        caption(label, size: size)
                    }
                }
            } else { ChalNaColor.surface }
        }
        .frame(width: width, height: h)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.sm))
        if store.phase == .done {
            Button { store.send(.playerPresentedChanged(true)) } label: { cover }
                .buttonStyle(.plain)
                .accessibilityLabel("완성된 영상 재생")
        } else { cover.accessibilityHidden(true) }
    }

    private func caption(_ label: ClipLabel, size: CGSize) -> some View {
        let font = label.fontPx(canvasHeight: size.height)
        let box = ClipLabelMetrics.paddedBoxSize(label.text, fontPx: font)
        return Text(verbatim: label.text)
            .font(Font(ClipLabelMetrics.uiFont(px: font)))
            .tracking(ClipLabel.BoxStyle.letterSpacing(for: font))
            .foregroundStyle(label.hasBackground ? ChalNaColor.onMediaDark : ChalNaColor.onMedia)
            .fixedSize()
            .frame(width: box.width, height: box.height)
            .background(label.hasBackground ? ChalNaColor.onMedia : .clear)
            .overlay {
                if label.hasBackground {
                    Rectangle().strokeBorder(ChalNaColor.onMediaDark, lineWidth: font * ClipLabel.BoxStyle.borderWidthFraction)
                }
            }
            .rotationEffect(label.previewRotation)
            .position(x: label.position.x * size.width, y: label.position.y * size.height)
    }

    private var completionLabel: some View {
        Text("필름이 완성됐어요").font(ChalNaTypography.label).foregroundStyle(ChalNaColor.accent)
    }

    @ViewBuilder
    private var information: some View {
        if store.phase == .idle {
            VStack(alignment: .leading, spacing: 8) {
                Text("출력 형식").font(ChalNaTypography.label).foregroundStyle(ChalNaColor.textSecondary)
                Text(verbatim: "\(store.resolution.width) × \(store.resolution.height) · 30fps")
                    .font(ChalNaTypography.headline)
                    .accessibilityIdentifier("export.outputFormat")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("생성 횟수").font(ChalNaTypography.label)
                if store.quotaUnlocked {
                    Text("2026년까지 영상 생성 제한이 해제됐어요.").font(ChalNaTypography.headline)
                } else {
                    Text("하루 2회 · 주 5회").font(ChalNaTypography.headline)
                    Text("만들기를 누르면 생성 횟수 1회를 사용해요.").font(ChalNaTypography.label)
                        .foregroundStyle(ChalNaColor.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ChalNaColor.selection, in: RoundedRectangle(cornerRadius: ChalNaRadius.sm))
        } else {
            saveRow(photo: false)
            saveRow(photo: true)
        }
    }

    private func saveRow(photo: Bool) -> some View {
        let status = photo ? store.photoStatus : store.archiveStatus
        return HStack(alignment: .top, spacing: 12) {
            ChalNaIcon(photo ? .download : .film, size: 16)
                .frame(width: 34, height: 34)
                .background(ChalNaColor.surface, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(photo ? LocalizedStringKey("사진 앱") : "내 필름").font(ChalNaTypography.headline)
                Group {
                    switch status {
                    case .idle, .saving: Text("저장 중…")
                    case .saved: Text(photo ? LocalizedStringKey("사진 앱에 저장했어요") : "앱에 보관했어요")
                    case .denied: Text("사진 추가 권한이 필요해요")
                    case .failed(let message): Text(verbatim: message)
                    }
                }
                .font(ChalNaTypography.label)
                .foregroundStyle(ChalNaColor.textSecondary)
                if status == .denied {
                    Button("설정 열기") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        returningFromSettings = true
                        openURL(url) { if !$0 { returningFromSettings = false } }
                    }
                    .buttonStyle(.chalNa(.ghost, size: .md))
                } else if case .failed = status {
                    Button(photo ? LocalizedStringKey("사진 앱에 다시 저장") : "보관 다시 시도") {
                        store.send(photo ? .saveToPhotoLibraryTapped : .archiveRequested)
                    }
                    .buttonStyle(.chalNa(.ghost, size: .md))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var actions: some View {
        if store.phase == .idle {
            HStack(spacing: 8) {
                Button("필름 만들기") {
                    store.send(.startExport(clips: session.clips, rotations: session.rotations,
                                            transforms: session.transforms, clipLabels: session.labels, title: session.title))
                }
                .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
                .disabled(session.clips.isEmpty)
                Button("편집 검토") { store.send(.backToEditTapped) }
                    .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
            }
        } else if let url = store.exportedURL {
            HStack(spacing: 8) {
                ShareLink(item: url) { Text("공유하기").frame(maxWidth: .infinity) }
                    .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
                Button("내 필름으로") { store.send(.homeTapped) }
                    .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
                    .contextMenu {
                        Button("다른 영상 만들기") { store.send(.startAnotherTapped) }
                    }
                    .accessibilityAction(named: Text("다른 영상 만들기")) { store.send(.startAnotherTapped) }
                    .disabled(archivePending)
            }
        }
    }

    private var progressView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GeometryReader { proxy in
                    let n = min(3, session.clips.count)
                    let width = max(0, proxy.size.width - CGFloat(max(0, n - 1)) * 8) / CGFloat(max(1, n))
                    HStack(spacing: 8) {
                        ForEach(session.clips.prefix(3)) { clip in
                            clip.thumbnailView()
                                .frame(width: width, height: 145)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.sm))
                        }
                    }
                }
                .frame(height: 145)
                Text("장면을 이어 붙이는 중").font(ChalNaTypography.title)
                Text(store.progress, format: .percent.precision(.fractionLength(0)))
                    .font(ChalNaTypography.display)
                    .foregroundStyle(ChalNaColor.accent)
                    .monospacedDigit()
                ChalNaProgressBar(progress: store.progress)
                Text("\(title) · 클립 \(count)개").font(ChalNaTypography.label)
                    .foregroundStyle(ChalNaColor.textSecondary)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 52)
            .frame(maxWidth: .infinity)
        }
    }

    private var failureView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            ChalNaIcon(.film, size: 28)
                .padding(15)
                .background(ChalNaColor.surface, in: Circle())
            if case let .limited(reason) = store.phase {
                Text(verbatim: reason.message).font(ChalNaTypography.title)
            } else {
                Text("필름을 만들지 못했어요").font(ChalNaTypography.title)
                if let message = store.errorMessage {
                    Text(verbatim: message).font(ChalNaTypography.body).foregroundStyle(ChalNaColor.textSecondary)
                }
            }
            Spacer()
            Button("편집으로 돌아가기") { store.send(.backToEditTapped) }
                .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
        }
        .padding(24)
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}
private struct ExportVideoPlayerCover: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.delegate = context.coordinator
        player.playWithFilmAudio()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

        func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator) {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.onDismiss()
            }
        }
    }
}
