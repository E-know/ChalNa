import SwiftUI
import CompositionService
import Models
import DesignSystem
import SwiftData
import Photos

/// Timeline에서 "저장"을 누르면 진입. 실제 `AVFoundationCompositionService`를 구동해
/// Live Photo의 paired video + 영상들을 이어 붙인 mp4를 만든다.
public struct ExportView: View {
    @Environment(AppRouter.self) private var router
    @Environment(EditSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @State private var progress: Double = 0
    @State private var phase: ExportPhase = .idle
    @State private var exportedURL: URL? = nil
    @State private var errorMessage: String? = nil
    @State private var exportTask: Task<Void, Never>?
    @State private var isSaving = false
    @State private var saveToast: String?
    /// 라이브러리에 한 번만 추가되도록 가드 (재진입 방지).
    @State private var didAddToLibrary = false

    private let compositionService: CompositionServicing

    public init(compositionService: CompositionServicing = AVFoundationCompositionService()) {
        self.compositionService = compositionService
    }

    public var body: some View {
        VStack(spacing: 0) {
            header.momentsHeaderBar()

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    cover(width: coverWidth(forAvailableHeight: proxy.size.height))
                        .padding(.top, MomentsSpacing.md)
                        .padding(.horizontal, MomentsSpacing.xl)

                    statusBlock
                        .padding(.horizontal, MomentsSpacing.lg)
                        .padding(.top, MomentsSpacing.xl)

                    Spacer(minLength: MomentsSpacing.md)

                    bottomCTAs
                        .padding(.horizontal, MomentsSpacing.md)
                        .padding(.bottom, MomentsSpacing.lg)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .momentsScreen()
        .onAppear { startExport() }
        .onDisappear { exportTask?.cancel() }
        .overlay(alignment: .bottom) {
            if let toast = saveToast {
                Text(toast)
                    .font(MomentsTypography.krBody(13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, MomentsSpacing.md)
                    .padding(.vertical, MomentsSpacing.xs)
                    .background(Capsule().fill(MomentsColor.ink.opacity(0.9)))
                    .padding(.bottom, MomentsSpacing.xxxl)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .task(id: toast) {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        await MainActor.run { saveToast = nil }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: saveToast)
    }

    // MARK: - Film library

    /// Export 가 완료될 때 mp4 를 Documents/films/ 로 복사하고 SwiftData 에 Film 레코드를 추가.
    /// 동일 export 세션 내 중복 추가 방지 위해 didAddToLibrary 플래그로 가드.
    private func addCompletedFilmToLibrary(at sourceURL: URL) {
        guard !didAddToLibrary else { return }
        didAddToLibrary = true

        let clips = session.clips
        let filmID = UUID()
        let movieFilename: String?
        do {
            movieFilename = try FilmStorage.importMovie(from: sourceURL, filmID: filmID)
        } catch {
            // 파일 복사가 실패하더라도 메타데이터는 남겨 두는 편이 사용자에겐 덜 당황스럽다.
            movieFilename = nil
        }

        let liveCount = clips.filter { $0.kind == .live }.count
        let totalDuration = clips.reduce(0) { $0 + $1.duration }
        let title = session.title.isEmpty ? "Moments" : session.title
        let thumbnail = clips.first?.thumbnailData

        let film = Film(
            id: filmID,
            title: title,
            createdAt: .now,
            movieFilename: movieFilename,
            thumbnailData: thumbnail,
            clipCount: clips.count,
            liveCount: liveCount,
            totalDurationSeconds: totalDuration
        )
        modelContext.insert(film)
        do {
            try modelContext.save()
        } catch {
            // 저장 실패해도 화면 흐름은 막지 않는다 — 다음 launch 에서 자동 복구됨.
        }
    }

    // MARK: - Photo library save

    private func saveToPhotoLibrary() {
        guard let url = exportedURL, !isSaving else { return }
        isSaving = true
        Task {
            let result = await Self.saveVideo(at: url)
            await MainActor.run {
                isSaving = false
                switch result {
                case .ok:       saveToast = "사진 앱에 저장됐어요 ✦"
                case .denied:   saveToast = "사진 보관함 접근 권한이 필요해요"
                case .failed(let msg): saveToast = "저장 실패 — \(msg)"
                }
            }
        }
    }

    private enum SaveResult { case ok, denied, failed(String) }

    private static func saveVideo(at url: URL) async -> SaveResult {
        guard await requestAddOnlyAuthorization() else { return .denied }
        return await withCheckedContinuation { (cont: CheckedContinuation<SaveResult, Never>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                if success {
                    cont.resume(returning: .ok)
                } else {
                    cont.resume(returning: .failed(error?.localizedDescription ?? "알 수 없는 오류"))
                }
            }
        }
    }

    private static func requestAddOnlyAuthorization() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let new = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return new == .authorized || new == .limited
        default:
            return false
        }
    }

    // MARK: - Header

    private var header: some View {
        // alignment: .top 으로 좌측 백 버튼과 가운데 2-line 타이틀의 첫 줄을 같은 y 에 정렬.
        // 우측 placeholder 는 좌측 버튼과 같은 view 트리 + opacity 0 으로 좌우 무게 균형을 맞춰
        // NavigationBar 가 위로 떠 보이지 않게 한다.
        HStack(alignment: .top) {
            backButton

            Spacer()

            VStack(spacing: 2) {
                Text(phase.title)
                    .font(MomentsTypography.krSemibold(15))
                    .foregroundColor(MomentsColor.ink)
                Text(phase.tag)
                    .tagLabel(color: phase.tagColor)
            }

            Spacer()

            backButton
                .opacity(0)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
    }

    private var backButton: some View {
        Button {
            router.pop()
        } label: {
            HStack(spacing: 2) {
                MomentsIcon(.chevronLeft, size: 14)
                Text("편집으로")
                    .font(MomentsTypography.krBody(14, weight: .medium))
            }
            .foregroundColor(MomentsColor.taupe)
        }
        .buttonStyle(.plain)
        .disabled(phase == .exporting)
        .opacity(phase == .exporting ? 0.4 : 1)
    }

    // MARK: - Cover

    /// 화면 가용 높이에서 PolaroidCard 가 잘리지 않도록 width 를 역산한다.
    /// PolaroidCard 시각 총 높이 ≈ (width - 24) × 5/4 + 92 (텍스트 여백 + topTape overhang).
    /// phase 별로 하단 CTA 영역의 높이가 다르므로 reservedHeight 도 분기한다.
    ///   .exporting: HandNoteRow 1행 (~24pt)
    ///   .done:      ShareLink+Save (1행) + 보조 CTA (1행) ≈ 120pt
    ///   .failed:    Retry + Back (2행) ≈ 110pt
    private func coverWidth(forAvailableHeight available: CGFloat) -> CGFloat {
        let reservedHeight: CGFloat = {
            switch phase {
            case .idle, .exporting: return 230
            case .done:             return 320
            case .failed:           return 310
            }
        }()
        let envelope = max(available - reservedHeight, 200)
        let widthFromHeight = (envelope - 92) * 4 / 5 + 24
        return min(max(widthFromHeight, 168), 300)
    }

    @ViewBuilder
    private func cover(width: CGFloat) -> some View {
        if let clip = session.clips.first {
            PolaroidCard(
                rotation: .center,
                width: width,
                caption: session.title.isEmpty ? SampleData.filmTitle : session.title,
                meta: metaLine,
                topTape: true
            ) {
                clip.thumbnailView()
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                if phase == .done {
                    StampBadge("Done", angle: 8)
                        .offset(x: -12, y: 10)
                }
            }
        } else {
            Text("내보낼 클립이 없어요")
                .font(MomentsTypography.krSemibold(16))
                .foregroundColor(MomentsColor.taupe)
        }
    }

    private var metaLine: String {
        let count = session.clips.count
        let videos = session.clips.filter { $0.videoURL != nil }.count
        let total = session.clips.reduce(0) { $0 + $1.duration }
        let m = Int(total) / 60
        let s = Int(total) % 60
        return String(format: "%d CLIPS · %d VIDEO · %02d:%02d", count, videos, m, s)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: MomentsSpacing.sm) {
            HStack {
                Text(statusLabelLeft)
                    .tagLabel(color: phase.tagColor)
                Spacer()
                if phase != .failed {
                    Text("\(Int(progress * 100))%")
                        .font(MomentsTypography.monoFallback(12, weight: .semibold))
                        .foregroundColor(MomentsColor.ink)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MomentsColor.ivory)
                        .frame(height: 6)
                    Capsule()
                        .fill(phase == .failed ? MomentsColor.taupe : MomentsColor.coral)
                        .frame(width: max(0, proxy.size.width * progress), height: 6)
                }
            }
            .frame(height: 6)

            Text(statusLine)
                .font(MomentsTypography.krBody(13))
                .foregroundColor(MomentsColor.taupe)
        }
    }

    private var statusLabelLeft: String {
        switch phase {
        case .idle, .exporting: return "EXPORT · IN PROGRESS"
        case .done:             return "EXPORT · COMPLETE"
        case .failed:           return "EXPORT · FAILED"
        }
    }

    private var statusLine: String {
        switch phase {
        case .idle, .exporting:
            return "Vlog를 엮는 중… Live Photo의 영상 부분을 자동으로 추출해 이어 붙여요."
        case .done:
            return "필름이 완성되었어요. 공유하거나 사진 보관함에 저장할 수 있어요."
        case .failed:
            return errorMessage ?? "저장 중 문제가 발생했어요."
        }
    }

    // MARK: - CTAs

    @ViewBuilder
    private var bottomCTAs: some View {
        switch phase {
        case .idle, .exporting:
            HandNoteRow("잠깐만 기다려주세요 ✦", icon: .film, tone: .muted, size: 16)
        case .done:
            VStack(spacing: MomentsSpacing.sm) {
                if let url = exportedURL {
                    HStack(spacing: MomentsSpacing.sm) {
                        ShareLink(item: url) {
                            HStack(spacing: 6) {
                                MomentsIcon(.share, size: 14)
                                Text("공유하기")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.momentsOutline)
                        .frame(maxWidth: .infinity)

                        Button {
                            saveToPhotoLibrary()
                        } label: {
                            HStack(spacing: 6) {
                                if isSaving {
                                    ProgressView().controlSize(.small).tint(.white)
                                } else {
                                    MomentsIcon(.download, size: 14)
                                }
                                Text(isSaving ? "저장 중…" : "저장하기")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.momentsCoral)
                        .frame(maxWidth: .infinity)
                        .disabled(isSaving)
                    }
                }

                HStack(spacing: MomentsSpacing.sm) {
                    Button("다른 영상 만들기") {
                        router.popToRoot()
                    }
                    .buttonStyle(.momentsOutline)
                    .frame(maxWidth: .infinity)

                    Button("홈으로 →") {
                        router.popToRoot()
                    }
                    .buttonStyle(.momentsText)
                    .frame(maxWidth: .infinity)
                }
            }
        case .failed:
            VStack(spacing: MomentsSpacing.sm) {
                Button {
                    startExport(force: true)
                } label: {
                    HStack(spacing: 8) {
                        MomentsIcon(.plus, size: 14)
                        Text("다시 시도")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.momentsCoral)

                Button("편집으로 돌아가기") { router.pop() }
                    .buttonStyle(.momentsOutline)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Export driver

    private func startExport(force: Bool = false) {
        guard !session.clips.isEmpty else { return }
        if !force && exportTask != nil { return }

        exportTask?.cancel()
        progress = 0
        phase = .exporting
        errorMessage = nil
        exportedURL = nil
        didAddToLibrary = false

        let clips = session.clips
        let rotations = session.rotations
        exportTask = Task {
            for await event in compositionService.export(clips: clips, rotations: rotations) {
                await MainActor.run {
                    switch event {
                    case .progress(let p):
                        progress = p
                        if phase != .exporting {
                            withAnimation(.easeInOut(duration: 0.35)) { phase = .exporting }
                        }
                    case .completed(let url):
                        progress = 1.0
                        exportedURL = url
                        withAnimation(.easeInOut(duration: 0.35)) { phase = .done }
                        addCompletedFilmToLibrary(at: url)
                    case .failed(let msg):
                        errorMessage = msg
                        withAnimation(.easeInOut(duration: 0.35)) { phase = .failed }
                    }
                }
            }
            await MainActor.run {
                exportTask = nil
            }
        }
    }
}

// MARK: - Phase

private enum ExportPhase: Equatable {
    case idle
    case exporting
    case done
    case failed

    var title: String {
        switch self {
        case .idle, .exporting: return "저장 중"
        case .done:             return "완성"
        case .failed:           return "저장 실패"
        }
    }
    var tag: String {
        switch self {
        case .idle, .exporting: return "EXPORTING"
        case .done:             return "DONE"
        case .failed:           return "FAILED"
        }
    }
    var tagColor: Color {
        switch self {
        case .idle, .exporting: return MomentsColor.coral
        case .done:             return MomentsColor.sage
        case .failed:           return MomentsColor.taupe
        }
    }
}

// MARK: - Preview helpers

/// Preview 전용 mock — 미리 정의한 ExportEvent 시퀀스를 스트림으로 흘려보낸다.
private struct PreviewCompositionService: CompositionServicing {
    let events: [ExportEvent]
    let interval: TimeInterval

    init(events: [ExportEvent], interval: TimeInterval = 0.5) {
        self.events = events
        self.interval = interval
    }

    func export(clips: [Clip], rotations: [Clip.ID: ClipRotation]) -> AsyncStream<ExportEvent> {
        let events = events
        let interval = interval
        return AsyncStream { continuation in
            let task = Task {
                for event in events {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    if Task.isCancelled { break }
                    continuation.yield(event)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

#Preview("Exporting") {
    let session = EditSession(title: SampleData.filmTitle, clips: SampleData.jejuTimeline)
    // 0.2 → 0.5 → 0.8 까지만 흘리고 멈춰 "저장 중" 상태 유지.
    let mock = PreviewCompositionService(events: [
        .progress(0.2), .progress(0.5), .progress(0.8)
    ])
    return ExportView(compositionService: mock)
        .environment(AppRouter())
        .environment(session)
        .modelContainer(for: Film.self, inMemory: true)
}

#Preview("Done") {
    let session = EditSession(title: SampleData.filmTitle, clips: SampleData.jejuTimeline)
    // 진행률 한 번 → 즉시 완료.
    let mock = PreviewCompositionService(
        events: [.progress(0.5), .completed(URL(fileURLWithPath: "/tmp/preview.mp4"))],
        interval: 0.2
    )
    return ExportView(compositionService: mock)
        .environment(AppRouter())
        .environment(session)
        .modelContainer(for: Film.self, inMemory: true)
}

#Preview("Failed") {
    let session = EditSession(title: SampleData.filmTitle, clips: SampleData.jejuTimeline)
    let mock = PreviewCompositionService(
        events: [.progress(0.3), .failed("Preview 용 가짜 실패 메시지")],
        interval: 0.2
    )
    return ExportView(compositionService: mock)
        .environment(AppRouter())
        .environment(session)
        .modelContainer(for: Film.self, inMemory: true)
}
