import SwiftUI
import AppCore
import Models
import DesignSystem
import PhotosService
import PhotosUI
import Photos
import AVFoundation
import UniformTypeIdentifiers
import OSLog
import UIKit

private let mediaLogger = Logger(subsystem: "ios.inho.OneSecMovie", category: "MediaPicker")

/// PhotosPicker 결과의 미디어 종류. Live Photo와 일반 영상은
/// 둘 다 "움직이는 클립"으로 다뤄지지만, UI에서는 분리해서 표시한다.
fileprivate enum MediaKind {
    case video
    case livePhoto
    case image
    case unknown

    var hasMotion: Bool { self == .video || self == .livePhoto }
}

public enum MediaPickerSource: Sendable {
    case photoLibrary
    case devFixtures(any DevMediaSourcing)
}

/// Live Photo + 영상을 여러 장 선택하고 Timeline으로 넘기는 화면.
/// 선택 시 (a) 썸네일 JPEG Data와 (b) 실제 비디오 파일 URL을 병렬로 로드한다.
/// Live Photo는 PhotosPicker의 Transferable에서 paired video가 안 나올 수 있어
/// `PHAssetResourceManager`로 paired video 리소스를 꺼내는 fallback을 둔다.
public struct MediaPickerView: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppRouter.self) private var router
    @Environment(EditSession.self) private var session

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var media: [PhotosPickerItem: MediaLoadState] = [:]
    @State private var devAssets: [DevMediaAsset] = []
    @State private var selectedDevAssetIDs: [DevMediaAsset.ID] = []
    @State private var devErrorMessage: String?
    @State private var isResolving = false
    @State private var isPhotoPickerPresented = false
    @State private var isPhotoPermissionAlertPresented = false
    @State private var scrollProgress: Double = 0
    @State private var titleInput: String = ""
    @FocusState private var isTitleFocused: Bool
    // PhotosPicker가 PHAsset localIdentifier(itemIdentifier)를 채워 주려면
    // photoLibrary 파라미터로 동일한 라이브러리를 명시해야 한다 (iOS 17+).
    @State private var photoLibrary = PHPhotoLibrary.shared()

    private let source: MediaPickerSource

    public init(source: MediaPickerSource = .photoLibrary) {
        self.source = source
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header 전체가 아니라 개별 버튼에만 Glass Effect를 부여해야 한다.
            header.momentsHeaderBar(scrollProgress: scrollProgress)
                .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })
                .zIndex(1)

            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: MomentsSpacing.lg) {
                        intro
                            .padding(.horizontal, MomentsSpacing.lg)
                            .padding(.top, MomentsSpacing.lg)
                            .trackScrollOffset(in: "media-picker-scroll")
                            .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })

                        titleField
                            .padding(.horizontal, MomentsSpacing.lg)

                        pickerLauncher
                            .padding(.horizontal, MomentsSpacing.lg)
                            .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })

                        selectionGrid
                            .padding(.horizontal, MomentsSpacing.lg)
                            .padding(.top, MomentsSpacing.sm)
                            .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })
                    }
                    .padding(.bottom, MomentsSpacing.huge)
                }
                .coordinateSpace(name: "media-picker-scroll")
                .scrollDismissesKeyboard(.interactively)
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { dismissTitleKeyboard() }
                )
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    let p = max(0, min(1, offset / 8))
                    if abs(p - scrollProgress) > 0.01 {
                        withAnimation(.easeInOut(duration: 0.15)) { scrollProgress = p }
                    }
                }

                bottomActionArea
                    .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })
            }
        }
        .momentsScreen()
        .alert("Live Photo 권한이 필요해요", isPresented: $isPhotoPermissionAlertPresented) {
            Button("확인") {
                openPhotoSettings()
            }
        } message: {
            Text("Live Photo를 영상으로 사용하려면 사진 보관함 접근 권한이 필요해요.")
        }
        .onChange(of: selectedItems) { _, newItems in
            syncMedia(for: newItems)
        }
        .task {
            await loadDevAssetsIfNeeded()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismissTitleKeyboard()
                router.pop()
            } label: {
                HStack(spacing: 2) {
                    MomentsIcon(.chevronLeft, size: 14)
                    Text("뒤로").font(MomentsTypography.krBody(14, weight: .medium))
                }
                .foregroundColor(MomentsColor.taupe)
            }
            .buttonStyle(.momentsHeaderAction)
            .accessibilityLabel("뒤로")

            Spacer()

            VStack(spacing: 2) {
                Text("미디어 선택")
                    .font(MomentsTypography.krSemibold(15))
                    .foregroundColor(MomentsColor.ink)
                Text("LIVE · VIDEO")
                    .tagLabel(color: MomentsColor.coral)
            }

            Spacer()

            Button {
                dismissTitleKeyboard()
                confirmSelection()
            } label: {
                if isResolving || isPreparingPhotoLibraryMedia {
                    ProgressView().controlSize(.small).tint(MomentsColor.coral)
                } else {
                    Text("다음")
                        .font(MomentsTypography.krSemibold(14))
                        .foregroundColor(canProceed ? MomentsColor.ink : MomentsColor.taupe.opacity(0.5))
                }
            }
            .buttonStyle(.momentsHeaderPrimaryAction)
            .accessibilityLabel(isResolving || isPreparingPhotoLibraryMedia ? "미디어 준비 중" : "다음")
            .accessibilityHint(confirmAccessibilityHint)
            .disabled(!canProceed || isResolving)
        }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: MomentsSpacing.xs) {
            Text("PICK · YOUR MOMENTS")
                .tagLabel()
            (Text("여행의 순간을\n")
                .font(MomentsTypography.displayKR(26))
             + Text("천천히 골라보세요.")
                .font(MomentsTypography.krBody(22, weight: .medium)))
                .foregroundColor(MomentsColor.ink)
                .lineSpacing(2)
            Text("Live Photo와 짧은 영상을 불러올 수 있어요. Live Photo는 내부의 영상 부분을 사용합니다.")
                .font(MomentsTypography.krBody(13))
                .foregroundColor(MomentsColor.taupe)
                .padding(.top, MomentsSpacing.xxs)
        }
    }

    // MARK: - Title field

    private var titleField: some View {
        VStack(alignment: .leading, spacing: MomentsSpacing.xs) {
            Text("TITLE · 이번 필름의 제목")
                .tagLabel()

            TextField(
                "",
                text: $titleInput,
                prompt: Text("예: 제주도, 우리의 봄")
                    .font(MomentsTypography.krBody(15))
                    .foregroundColor(MomentsColor.taupe.opacity(0.6))
            )
            .textFieldStyle(.plain)
            .font(MomentsTypography.krBody(16, weight: .medium))
            .foregroundColor(MomentsColor.ink)
            .submitLabel(.done)
            .onSubmit { isTitleFocused = false }
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .focused($isTitleFocused)
            .accessibilityLabel("이번 필름의 제목")
            .padding(.horizontal, MomentsSpacing.md)
            .padding(.vertical, MomentsSpacing.sm + 2)
            .frame(minHeight: MomentsSpacing.minimumHitTarget + MomentsSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .strokeBorder(
                        isTitleFocused
                            ? MomentsColor.coral.opacity(0.55)
                            : MomentsColor.taupe.opacity(0.18),
                        lineWidth: 1
                    )
            )

            Text("비워두면 나중에 자동으로 채워져요.")
                .font(MomentsTypography.krBody(12))
                .foregroundColor(MomentsColor.taupe)
        }
    }

    // MARK: - Picker launcher

    @ViewBuilder
    private var pickerLauncher: some View {
        switch source {
        case .photoLibrary:
            photoLibraryPickerLauncher
        case .devFixtures:
            devFixtureLauncher
        }
    }

    private var photoLibraryPickerLauncher: some View {
        Button {
            dismissTitleKeyboard()
            isPhotoPickerPresented = true
        } label: {
            HStack(spacing: MomentsSpacing.sm) {
                MomentsIcon(.plus, size: 18)
                    .foregroundColor(MomentsColor.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedItems.isEmpty ? "사진 보관함 열기" : "선택 다시 고르기")
                        .font(MomentsTypography.krSemibold(15))
                        .foregroundColor(MomentsColor.ink)
                    Text(selectedItems.isEmpty ? "Live Photo · Video 자유롭게"
                                               : "\(selectedItems.count)장 선택됨")
                        .font(MomentsTypography.krBody(12))
                        .foregroundColor(MomentsColor.taupe)
                }
                Spacer()
                MomentsIcon(.chevronRight, size: 14)
                    .foregroundColor(MomentsColor.taupe)
            }
            .padding(MomentsSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .strokeBorder(MomentsColor.coral.opacity(0.5),
                                  style: .init(lineWidth: 1.2, dash: selectedItems.isEmpty ? [5, 3] : []))
            )
        }
        .buttonStyle(.plain)
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedItems,
            maxSelectionCount: 0,
            selectionBehavior: .ordered,
            matching: .any(of: [.livePhotos, .videos]),
            photoLibrary: photoLibrary
        )
        .accessibilityLabel(selectedItems.isEmpty ? "사진 보관함 열기" : "선택 다시 고르기")
        .accessibilityHint("Live Photo와 영상을 선택합니다.")
    }

    private var devFixtureLauncher: some View {
        VStack(alignment: .leading, spacing: MomentsSpacing.xs) {
            HStack(spacing: MomentsSpacing.sm) {
                MomentsIcon(.film, size: 18)
                    .foregroundColor(MomentsColor.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dev 미디어 소스")
                        .font(MomentsTypography.krSemibold(15))
                        .foregroundColor(MomentsColor.ink)
                    Text(selectedDevAssetIDs.isEmpty ? "번들 fixture로 실제 export까지 확인"
                                                     : "\(selectedDevAssetIDs.count)개 fixture 선택됨")
                        .font(MomentsTypography.krBody(12))
                        .foregroundColor(MomentsColor.taupe)
                }
                Spacer()
                StampBadge("DEV", angle: 6)
            }
            .padding(MomentsSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .strokeBorder(MomentsColor.coral.opacity(0.45), lineWidth: 1.2)
            )

            if let devErrorMessage {
                Text(devErrorMessage)
                    .font(MomentsTypography.krBody(12))
                    .foregroundColor(MomentsColor.coral)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dev 미디어 소스")
    }

    // MARK: - Selection grid / empty

    @ViewBuilder
    private var selectionGrid: some View {
        switch source {
        case .photoLibrary:
            photoLibrarySelectionGrid
        case .devFixtures:
            devFixtureSelectionGrid
        }
    }

    @ViewBuilder
    private var photoLibrarySelectionGrid: some View {
        if selectedItems.isEmpty {
            VStack(alignment: .leading, spacing: MomentsSpacing.sm) {
                Text("SELECTED · 0")
                    .tagLabel()
                HandNoteRow("사진을 추가해 필름을 시작해보세요 ✦",
                            tone: .muted, size: 17, alignment: .leading)
                    .padding(.vertical, MomentsSpacing.lg)
            }
        } else {
            VStack(alignment: .leading, spacing: MomentsSpacing.sm) {
                HStack(spacing: MomentsSpacing.xs) {
                    Text("SELECTED · \(selectedItems.count)")
                        .tagLabel()
                    Spacer()
                    if liveCount > 0 {
                        MomentsChip("\(liveCount) LIVE", variant: .live)
                    }
                    if videoCount > 0 {
                        MomentsChip("\(videoCount) VIDEO", variant: .video, icon: .film)
                    }
                }
                if let photoLibraryStatusMessage {
                    HStack(spacing: MomentsSpacing.xs) {
                        if isPreparingPhotoLibraryMedia {
                            ProgressView()
                                .controlSize(.small)
                                .tint(MomentsColor.coral)
                        } else {
                            MomentsIcon(.download, size: 12)
                        }
                        Text(photoLibraryStatusMessage)
                            .font(MomentsTypography.krBody(12, weight: .medium))
                    }
                    .foregroundColor(photoLibraryStatusColor)
                    .padding(.horizontal, MomentsSpacing.sm)
                    .padding(.vertical, MomentsSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                            .fill(MomentsColor.ivory.opacity(0.75))
                    )
                    .accessibilityElement(children: .combine)
                }
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: MomentsSpacing.sm), count: 3),
                    spacing: MomentsSpacing.sm
                ) {
                    ForEach(Array(selectedItems.enumerated()), id: \.offset) { idx, item in
                        ClipThumbCard(
                            state: .normal,
                            rotationDegrees: rotation(for: idx),
                            size: CGSize(width: 84, height: 108)
                        ) {
                            thumbnailContent(for: item)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(thumbnailAccessibilityLabel(for: item, index: idx))
                    }
                }
                .padding(.vertical, MomentsSpacing.sm)
            }
        }
    }

    @ViewBuilder
    private var devFixtureSelectionGrid: some View {
        VStack(alignment: .leading, spacing: MomentsSpacing.sm) {
            HStack(spacing: MomentsSpacing.xs) {
                Text("DEV FIXTURES · \(selectedDevAssetIDs.count)")
                    .tagLabel()
                Spacer()
                if devLiveCount > 0 {
                    MomentsChip("\(devLiveCount) LIVE", variant: .live)
                }
                if devVideoCount > 0 {
                    MomentsChip("\(devVideoCount) VIDEO", variant: .video, icon: .film)
                }
            }

            if devAssets.isEmpty {
                HandNoteRow("Dev 미디어를 준비하고 있어요 ✦",
                            tone: .muted, size: 17, alignment: .leading)
                    .padding(.vertical, MomentsSpacing.lg)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: MomentsSpacing.sm), count: 2),
                    spacing: MomentsSpacing.md
                ) {
                    ForEach(Array(devAssets.enumerated()), id: \.element.id) { idx, asset in
                        let isSelected = selectedDevAssetIDs.contains(asset.id)
                        Button {
                            dismissTitleKeyboard()
                            toggleDevAsset(asset.id)
                        } label: {
                            DevMediaAssetCard(
                                asset: asset,
                                isSelected: isSelected,
                                rotationDegrees: rotation(for: idx)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(asset.title), \(asset.kind == .live ? "라이브 포토" : "비디오")")
                        .accessibilityHint(isSelected ? "선택됨. 두 번 탭하면 선택을 해제합니다." : "두 번 탭하면 선택합니다.")
                    }
                }
                .padding(.vertical, MomentsSpacing.sm)
            }
        }
    }

    @ViewBuilder
    private func thumbnailContent(for item: PhotosPickerItem) -> some View {
        let state = media[item] ?? MediaLoadState()
        ZStack {
            if let data = state.thumbnail, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if state.thumbnailFailed {
                failedPlaceholder
            } else {
                MomentsColor.ivory
                ProgressView()
                    .tint(MomentsColor.coral)
            }

            // 좌상단: 미디어 종류 칩 (LIVE / VIDEO)
            kindChip(for: state.kind)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(4)

            // 일반 영상에만 중앙 재생 동그라미. Live Photo는 칩으로만 구분.
            if state.kind == .video {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 22, height: 22)
                    .overlay(MomentsIcon(.play, size: 9).foregroundColor(MomentsColor.ink).offset(x: 1))
            }

            if state.videoFailed && state.thumbnail != nil {
                // 동영상 추출 실패 표식 (모서리 작은 배지).
                Text("영상 X")
                    .font(MomentsTypography.monoFallback(8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(MomentsColor.taupe.opacity(0.9)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(4)
            }
        }
    }

    @ViewBuilder
    private func kindChip(for kind: MediaKind) -> some View {
        switch kind {
        case .livePhoto:
            MomentsChip("LIVE", variant: .live)
                .scaleEffect(0.78, anchor: .topLeading)
        case .video:
            MomentsChip("VIDEO", variant: .video, icon: .film)
                .scaleEffect(0.78, anchor: .topLeading)
        case .image, .unknown:
            EmptyView()
        }
    }

    private var failedPlaceholder: some View {
        ZStack {
            MomentsColor.ivory
            MomentsIcon(.close, size: 14).foregroundColor(MomentsColor.taupe)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Bottom bar

    private var bottomActionArea: some View {
        bottomBar
            .padding(.horizontal, MomentsSpacing.md)
            .padding(.top, MomentsSpacing.xs)
            .padding(.bottom, MomentsSpacing.md)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if #available(iOS 26.0, *) {
            liquidGlassBottomBar
        } else {
            momentsBottomBar
        }
    }

    @available(iOS 26.0, *)
    private var liquidGlassBottomBar: some View {
        GlassEffectContainer(spacing: MomentsSpacing.xs) {
            HStack(spacing: MomentsSpacing.xs) {
                Button {
                    dismissTitleKeyboard()
                    router.pop()
                } label: {
                    Text("취소")
                        .foregroundStyle(MomentsColor.ink)
                        .frame(maxWidth: .infinity, minHeight: MomentsSpacing.minimumHitTarget)
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)

                Button {
                    dismissTitleKeyboard()
                    confirmSelection()
                } label: {
                    confirmBottomLabel
                        .foregroundStyle(MomentsColor.ink)
                        .frame(maxWidth: .infinity, minHeight: MomentsSpacing.minimumHitTarget)
                }
                .buttonStyle(.glassProminent)
                .tint(MomentsColor.coral)
                .frame(maxWidth: .infinity)
                .disabled(!canProceed || isResolving)
                .opacity(canProceed ? 1 : 0.5)
                .accessibilityLabel(confirmButtonTitle)
                .accessibilityHint(confirmAccessibilityHint)
            }
        }
    }

    private var momentsBottomBar: some View {
        HStack(spacing: MomentsSpacing.xs) {
            Button {
                dismissTitleKeyboard()
                router.pop()
            } label: {
                Text("취소")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.momentsOutline)
            .frame(maxWidth: .infinity)

            Button {
                dismissTitleKeyboard()
                confirmSelection()
            } label: {
                confirmBottomLabel
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.momentsCoral)
            .frame(maxWidth: .infinity)
            .disabled(!canProceed || isResolving)
            .opacity(canProceed ? 1 : 0.5)
            .accessibilityLabel(confirmButtonTitle)
            .accessibilityHint(confirmAccessibilityHint)
        }
    }

    private var confirmBottomLabel: some View {
        HStack(spacing: 6) {
            if isResolving || isPreparingPhotoLibraryMedia {
                ProgressView().controlSize(.small).tint(MomentsColor.ink)
            } else {
                MomentsIcon(.check, size: 14)
            }
            Text(confirmButtonTitle)
        }
    }

    // MARK: - Derived

    private var canProceed: Bool {
        switch source {
        case .photoLibrary:
            return !selectedItems.isEmpty && selectedItems.allSatisfy { item in
                media[item]?.isReadyForTimeline == true
            }
        case .devFixtures:
            return !selectedDevAssetIDs.isEmpty
        }
    }

    private var isPreparingPhotoLibraryMedia: Bool {
        guard case .photoLibrary = source, !selectedItems.isEmpty else { return false }
        return !canProceed && !hasUnavailablePhotoLibraryMedia
    }

    private var hasUnavailablePhotoLibraryMedia: Bool {
        guard case .photoLibrary = source else { return false }
        return selectedItems.contains { item in
            media[item]?.didFailTimelinePreparation == true
        }
    }

    private var needsLivePhotoAuthorization: Bool {
        guard case .photoLibrary = source, !Self.hasPhotoAuthorization else { return false }
        return selectedItems.contains { item in
            let state = media[item]
            return state?.kind == .livePhoto && state?.videoFailed == true
        }
    }

    private var readyPhotoLibraryMediaCount: Int {
        selectedItems.reduce(into: 0) { count, item in
            if media[item]?.isReadyForTimeline == true {
                count += 1
            }
        }
    }

    private var photoLibraryStatusMessage: String? {
        guard case .photoLibrary = source, !selectedItems.isEmpty else { return nil }
        if needsLivePhotoAuthorization {
            return "Live Photo를 영상으로 사용하려면 사진 권한이 필요해요."
        }
        if hasUnavailablePhotoLibraryMedia {
            return "선택한 항목을 불러오지 못했어요. 다시 선택해 주세요."
        }
        if readyPhotoLibraryMediaCount < selectedItems.count {
            return "사진 로딩 중 · \(readyPhotoLibraryMediaCount)/\(selectedItems.count)"
        }
        return nil
    }

    private var photoLibraryStatusColor: Color {
        hasUnavailablePhotoLibraryMedia ? MomentsColor.coral : MomentsColor.taupe
    }

    private var confirmButtonTitle: String {
        if selectedCount == 0 {
            return "선택 후 다음"
        }
        if case .photoLibrary = source {
            if needsLivePhotoAuthorization {
                return "권한 필요"
            }
            if hasUnavailablePhotoLibraryMedia {
                return "원본 확인 필요"
            }
            if !canProceed {
                return "사진 로딩 중"
            }
        }
        return "Timeline으로 (\(selectedCount))"
    }

    private var confirmAccessibilityHint: String {
        if isResolving {
            return "선택한 미디어를 타임라인으로 넘기고 있습니다."
        }
        switch source {
        case .photoLibrary:
            if selectedItems.isEmpty {
                return "미디어를 선택하면 다음 단계로 이동할 수 있습니다."
            }
            if needsLivePhotoAuthorization {
                return "Live Photo 영상 추출을 위해 사진 권한이 필요합니다."
            }
            if hasUnavailablePhotoLibraryMedia {
                return "iCloud 원본을 모두 불러오지 못해 타임라인으로 이동할 수 없습니다."
            }
            if !canProceed {
                return "선택한 모든 사진과 영상 로딩이 끝나면 타임라인으로 이동할 수 있습니다."
            }
            return "선택한 미디어로 타임라인을 만듭니다."
        case .devFixtures:
            return canProceed ? "선택한 미디어로 타임라인을 만듭니다." : "미디어를 선택하면 다음 단계로 이동할 수 있습니다."
        }
    }

    private var selectedCount: Int {
        switch source {
        case .photoLibrary:
            return selectedItems.count
        case .devFixtures:
            return selectedDevAssetIDs.count
        }
    }

    private func dismissTitleKeyboard() {
        isTitleFocused = false
    }

    private var liveCount: Int {
        selectedItems.reduce(into: 0) { acc, item in
            if media[item]?.kind == .livePhoto { acc += 1 }
        }
    }

    private var videoCount: Int {
        selectedItems.reduce(into: 0) { acc, item in
            if media[item]?.kind == .video { acc += 1 }
        }
    }

    private var devLiveCount: Int {
        devAssets.reduce(into: 0) { acc, asset in
            if selectedDevAssetIDs.contains(asset.id), asset.kind == .live { acc += 1 }
        }
    }

    private var devVideoCount: Int {
        devAssets.reduce(into: 0) { acc, asset in
            if selectedDevAssetIDs.contains(asset.id), asset.kind == .video { acc += 1 }
        }
    }

    private func thumbnailAccessibilityLabel(for item: PhotosPickerItem, index: Int) -> String {
        let state = media[item] ?? MediaLoadState()
        var parts = ["\(index + 1)번째 선택한 미디어", accessibilityLabel(for: state.kind)]
        if !state.isFullyLoaded {
            parts.append("불러오는 중")
        }
        if state.thumbnailFailed {
            parts.append("썸네일 불러오기 실패")
        }
        if state.videoFailed {
            parts.append("영상 추출 실패")
        }
        return parts.joined(separator: ", ")
    }

    private func accessibilityLabel(for kind: MediaKind) -> String {
        switch kind {
        case .video:     return "비디오"
        case .livePhoto: return "라이브 포토"
        case .image:     return "사진"
        case .unknown:   return "종류 확인 중"
        }
    }

    // MARK: - Load pipeline

    private func syncMedia(for newItems: [PhotosPickerItem]) {
        let retained = Set(newItems)
        media = media.filter { retained.contains($0.key) }

        for item in newItems where media[item] == nil {
            let initialKind = Self.classify(item)
            media[item] = MediaLoadState(kind: initialKind, isLoading: true)

            Task {
                async let thumbnail: Data? = Self.loadThumbnail(for: item, kind: initialKind)
                async let videoURLTask: URL? = Self.loadVideoURL(for: item, kind: initialKind)
                async let capturedAt: Date? = Self.loadCapturedAt(for: item)

                // duration·displaySize 는 videoURL 이 결정된 뒤에야 읽을 수 있어 직렬 의존.
                let url = await videoURLTask
                async let durTask: TimeInterval? = Self.loadVideoDuration(from: url)
                async let sizeTask: CGSize? = Self.loadDisplaySize(from: url)
                let (thumb, captured, dur, size) = await (thumbnail, capturedAt, durTask, sizeTask)

                await MainActor.run {
                    guard var state = media[item] else { return }
                    state.thumbnail = thumb
                    state.thumbnailFailed = (thumb == nil)
                    state.videoURL = url
                    state.videoFailed = (url == nil)
                    state.duration = dur
                    state.capturedAt = captured
                    state.displaySize = size
                    state.isLoading = false
                    media[item] = state
                    if initialKind == .livePhoto, url == nil, !Self.hasPhotoAuthorization {
                        isPhotoPermissionAlertPresented = true
                    }
                }
            }
        }
    }

    private func loadDevAssetsIfNeeded() async {
        guard case .devFixtures(let mediaSource) = source else { return }
        let assets = await mediaSource.availableAssets()
        await MainActor.run {
            devAssets = assets
        }
    }

    private func toggleDevAsset(_ id: DevMediaAsset.ID) {
        devErrorMessage = nil
        if let index = selectedDevAssetIDs.firstIndex(of: id) {
            selectedDevAssetIDs.remove(at: index)
        } else {
            selectedDevAssetIDs.append(id)
        }
    }

    // MARK: - Capture date (EXIF / PHAsset.creationDate)

    /// 이미 사진 읽기 권한이 있으면 실제 촬영 일자를 PHAsset.creationDate 에서 가져온다.
    /// PHAsset.creationDate 는 사진 import 시 EXIF DateTimeOriginal 로 채워지므로
    /// "EXIF 촬영 시각" 과 사실상 동일하다.
    private static func loadCapturedAt(for item: PhotosPickerItem) async -> Date? {
        guard hasPhotoAuthorization else { return nil }
        guard let localID = item.itemIdentifier else { return nil }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
        return fetch.firstObject?.creationDate
    }

    // MARK: - Video duration

    /// 영상 파일의 실제 재생 길이(초). Live Photo paired video / 일반 영상 모두 동일 경로.
    /// 권한·코덱 등으로 실패 시 nil → 호출 측에서 fallback 길이를 적용.
    private static func loadVideoDuration(from url: URL?) async -> TimeInterval? {
        guard let url else { return nil }
        let asset = AVURLAsset(url: url)
        do {
            let cm = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(cm)
            return seconds.isFinite && seconds > 0 ? seconds : nil
        } catch {
            return nil
        }
    }

    // MARK: - Display size

    /// 비디오 트랙의 `naturalSize`에 `preferredTransform`을 적용한 표시상 사이즈.
    /// 세로 영상(rotation 90°)이면 width < height 형태로 정규화돼 나온다.
    /// 합성 시 출력 캔버스 결정과 가운데 정렬에 쓰인다.
    private static func loadDisplaySize(from url: URL?) async -> CGSize? {
        guard let url else { return nil }
        let asset = AVURLAsset(url: url)
        guard let track = (try? await asset.loadTracks(withMediaType: .video))?.first else {
            return nil
        }
        let natural = (try? await track.load(.naturalSize)) ?? .zero
        let transform = (try? await track.load(.preferredTransform)) ?? .identity
        let display = natural.applying(transform)
        let w = abs(display.width)
        let h = abs(display.height)
        guard w > 0, h > 0 else { return nil }
        return CGSize(width: w, height: h)
    }

    // MARK: - Classification

    fileprivate static func classify(_ item: PhotosPickerItem) -> MediaKind {
        let types = item.supportedContentTypes
        // livePhoto는 .image와 .movie 양쪽에 conform될 수 있으므로 가장 먼저 검사.
        if types.contains(where: { $0.conforms(to: .livePhoto) }) { return .livePhoto }
        if types.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .audiovisualContent) }) { return .video }
        // 이 피커는 `.livePhotos`와 `.videos`만 허용한다. PhotosPickerItem이 Live Photo를
        // `.image`로만 보고하는 경우가 있어, 여기서는 still image가 아니라 Live Photo로 취급한다.
        if types.contains(where: { $0.conforms(to: .image) }) { return .livePhoto }
        return .unknown
    }

    // MARK: - Thumbnail

    private static func loadThumbnail(for item: PhotosPickerItem, kind: MediaKind) async -> Data? {
        // PhotosPicker의 기본 Data는 Live Photo의 경우 스틸 JPEG을 준다. 썸네일로는 그대로 OK.
        if let data = try? await item.loadTransferable(type: Data.self) {
            if let ui = UIImage(data: data), let jpeg = ui.jpegData(compressionQuality: 0.75) {
                return jpeg
            }
            // 동영상의 경우 Data는 영상 원본이므로 AVAssetImageGenerator로 프레임 추출.
            if kind == .video {
                if let thumb = await videoThumbnailData(from: data) {
                    return thumb
                }
            }
        }
        return nil
    }

    private static func videoThumbnailData(from videoData: Data) async -> Data? {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumb-\(UUID().uuidString).mov")
        do {
            try videoData.write(to: tmp)
        } catch {
            return nil
        }
        defer { try? FileManager.default.removeItem(at: tmp) }

        let asset = AVURLAsset(url: tmp)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 480, height: 480)
        do {
            let cgImage = try await gen.image(at: .zero).image
            return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.75)
        } catch {
            return nil
        }
    }

    // MARK: - Video URL

    private static func loadVideoURL(for item: PhotosPickerItem, kind: MediaKind) async -> URL? {
        // Live Photo: 피커는 권한 없이 열되, 선택 후에는 paired video 추출을 위해 권한을 요청한다.
        if kind == .livePhoto {
            guard await ensurePhotoAuthorization() else {
                mediaLogger.error("Photo library authorization not granted for Live Photo paired video")
                return nil
            }
            return await loadViaPHAsset(item: item)
        }

        // 일반 영상: 빠른 경로로 VideoPayload 시도, 실패 시 PHAsset fallback.
        do {
            if let payload = try await item.loadTransferable(type: VideoPayload.self) {
                return payload.url
            }
        } catch {
            mediaLogger.error("VideoPayload transfer failed: \(error.localizedDescription, privacy: .public)")
        }
        return await loadViaPHAsset(item: item)
    }

    /// 기존 사진 읽기 권한이 있을 때만 paired video / 원본 영상을 temp 파일로 내림.
    private static func loadViaPHAsset(item: PhotosPickerItem) async -> URL? {
        mediaLogger.debug("loadViaPHAsset start, hasItemID=\(item.itemIdentifier != nil, privacy: .public)")
        guard hasPhotoAuthorization else {
            mediaLogger.info("Photo library authorization unavailable; continue with picker payload")
            return nil
        }
        guard let localID = item.itemIdentifier else {
            mediaLogger.error("PhotosPickerItem.itemIdentifier was nil — PhotosPicker(photoLibrary:) 누락 여부 점검 필요")
            return nil
        }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
        guard let asset = fetch.firstObject else {
            mediaLogger.error("PHAsset fetch missed for given identifier")
            return nil
        }

        // 우선순위: Live Photo paired video → 원본 영상.
        let resources = PHAssetResource.assetResources(for: asset)
        let preferredTypes: [PHAssetResourceType] = [
            .pairedVideo, .fullSizePairedVideo,
            .video, .fullSizeVideo
        ]
        guard let resource = preferredTypes
                .lazy.compactMap({ type in resources.first(where: { $0.type == type }) })
                .first
        else {
            mediaLogger.warning("No paired/full video resource on asset")
            return nil
        }

        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("paired-\(UUID().uuidString).mov")
        try? FileManager.default.removeItem(at: destURL)

        do {
            try await writePHAssetResource(resource, to: destURL)
            return destURL
        } catch {
            mediaLogger.error("PHAssetResource writeData failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// iCloud 미디어도 네트워크로 당겨 로컬에 저장.
    private static func writePHAssetResource(_ resource: PHAssetResource, to url: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    private func openPhotoSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    /// 시스템 권한 프롬프트 없이 현재 사진 읽기 권한만 확인한다.
    private static var hasPhotoAuthorization: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }

    /// Live Photo의 paired video 추출 직전에만 사진 권한을 요청한다.
    private static func ensurePhotoAuthorization() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }

    // MARK: - Confirm

    private func confirmSelection() {
        switch source {
        case .photoLibrary:
            confirmPhotoLibrarySelection()
        case .devFixtures(let source):
            confirmDevFixtureSelection(source)
        }
    }

    private func confirmPhotoLibrarySelection() {
        guard canProceed, !isResolving else { return }
        isResolving = true

        let items = selectedItems

        Task {
            let latest = await MainActor.run { self.media }
            guard items.allSatisfy({ latest[$0]?.isReadyForTimeline == true }) else {
                await MainActor.run {
                    isResolving = false
                }
                return
            }

            let presetPool: [ThumbnailPreset] = [
                .jejuSea, .jejuOrange, .hallasan, .seoulSun,
                .field, .forest, .sunset, .cafe
            ]
            // EXIF 시각이 안 잡힌 항목의 fallback (권한 거부 등 예외 케이스).
            let fallback = Date()

            let clips: [Clip] = items.enumerated().map { idx, item in
                let state = latest[item] ?? MediaLoadState()
                let kind: ClipKind = (state.kind == .video) ? .video : .live
                return Clip(
                    kind: kind,
                    capturedAt: state.capturedAt ?? fallback.addingTimeInterval(TimeInterval(idx) * 60),
                    duration: state.duration ?? 3.0,
                    preset: presetPool[idx % presetPool.count],
                    thumbnailData: state.thumbnail,
                    videoURL: state.videoURL,
                    locationNote: nil,
                    displaySize: state.displaySize
                )
            }

            // 촬영일 오름차순(오래된 것 먼저 → 최신)으로 정렬해 Timeline에 넘긴다.
            // export 시 클립 순서가 그대로 mp4에 반영되므로, 결과 영상도 시간순으로 흐른다.
            let orderedClips = clips.sorted { $0.capturedAt < $1.capturedAt }

            await MainActor.run {
                isResolving = false
                guard !orderedClips.isEmpty else { return }
                let trimmed = titleInput.trimmingCharacters(in: .whitespacesAndNewlines)
                session.replace(clips: orderedClips, title: trimmed)
                router.push(.timeline)
            }
        }
    }

    private func confirmDevFixtureSelection(_ source: any DevMediaSourcing) {
        guard canProceed, !isResolving else { return }
        isResolving = true
        devErrorMessage = nil

        let ids = selectedDevAssetIDs
        Task {
            do {
                let clips = try await source.resolve(assetIDs: ids)
                let orderedClips = clips.sorted { $0.capturedAt < $1.capturedAt }

                await MainActor.run {
                    isResolving = false
                    guard !orderedClips.isEmpty else { return }
                    let trimmed = titleInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    session.replace(clips: orderedClips, title: trimmed)
                    router.push(.timeline)
                }
            } catch {
                await MainActor.run {
                    isResolving = false
                    devErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func rotation(for index: Int) -> Double {
        switch index % 4 {
        case 0: return -1.2
        case 1: return 0.8
        case 2: return -0.3
        default: return 1.2
        }
    }
}

// MARK: - State & payload

private struct MediaLoadState {
    var kind: MediaKind = .unknown
    var thumbnail: Data? = nil
    var videoURL: URL? = nil
    var duration: TimeInterval? = nil
    var capturedAt: Date? = nil
    var displaySize: CGSize? = nil
    var isLoading: Bool = false
    var thumbnailFailed: Bool = false
    var videoFailed: Bool = false

    var isFullyLoaded: Bool {
        !isLoading && (thumbnail != nil || thumbnailFailed) && (videoURL != nil || videoFailed)
    }

    var isReadyForTimeline: Bool {
        !isLoading && thumbnail != nil && (!kind.hasMotion || videoURL != nil)
    }

    var didFailTimelinePreparation: Bool {
        !isLoading && (thumbnail == nil || (kind.hasMotion && videoURL == nil))
    }
}

/// `FileRepresentation`을 통해 PhotosPicker에서 동영상 파일 URL을 temp 디렉터리로 복사받는 전송 타입.
private struct VideoPayload: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { payload in
            SentTransferredFile(payload.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("movie-\(UUID().uuidString).mov")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return VideoPayload(url: dest)
        }
    }
}

#Preview("MediaPicker — empty") {
    MediaPickerView()
        .environment(AppRouter())
        .environment(EditSession())
}

#Preview("MediaPicker — Dev") {
    MediaPickerView(source: .devFixtures(BundledDevMediaSource()))
        .environment(AppRouter())
        .environment(EditSession())
}

private struct DevMediaAssetCard: View {
    let asset: DevMediaAsset
    let isSelected: Bool
    let rotationDegrees: Double

    var body: some View {
        VStack(alignment: .leading, spacing: MomentsSpacing.xs) {
            ClipThumbCard(
                state: isSelected ? .selected : .normal,
                rotationDegrees: rotationDegrees,
                size: CGSize(width: 112, height: 142)
            ) {
                ZStack {
                    asset.preset.view()
                    LinearGradient(
                        colors: [.clear, MomentsColor.ink.opacity(0.5)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    kindChip
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(4)
                    if asset.kind == .video {
                        Circle()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 24, height: 24)
                            .overlay(
                                MomentsIcon(.play, size: 10)
                                    .foregroundColor(MomentsColor.ink)
                                    .offset(x: 1)
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.title)
                    .font(MomentsTypography.krSemibold(13))
                    .foregroundColor(MomentsColor.ink)
                    .lineLimit(1)
                Text(asset.locationNote ?? asset.durationLabel)
                    .font(MomentsTypography.krBody(11))
                    .foregroundColor(MomentsColor.taupe)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(MomentsSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 1 : 0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                .strokeBorder(isSelected ? MomentsColor.coral : MomentsColor.taupe.opacity(0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var kindChip: some View {
        switch asset.kind {
        case .live:
            MomentsChip("LIVE", variant: .live)
                .scaleEffect(0.72, anchor: .topLeading)
        case .video:
            MomentsChip("VIDEO", variant: .video, icon: .film)
                .scaleEffect(0.72, anchor: .topLeading)
        }
    }
}

private extension DevMediaAsset {
    var durationLabel: String {
        String(format: "%.1fs", duration)
    }
}
