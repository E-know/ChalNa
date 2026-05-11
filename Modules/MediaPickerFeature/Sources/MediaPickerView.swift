import SwiftUI
import AppCore
import Models
import DesignSystem
import PhotosService
import PhotosUI
import Photos
import AVFoundation
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
/// 먼저 사진 권한 범위를 확정한 뒤, PhotoKit에서 접근 가능한 asset만 자체 그리드에 표시한다.
/// Live Photo는 `PHAssetResourceManager`로 paired video 리소스를 꺼낸다.
public struct MediaPickerView: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppRouter.self) private var router
    @Environment(EditSession.self) private var session

    @State private var photoAssets: [PhotoLibraryAsset] = []
    @State private var selectedAssetIDs: [String] = []
    @State private var media: [String: MediaLoadState] = [:]
    @State private var assetThumbnails: [String: Data] = [:]
    @State private var photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var isPhotoLibraryLoading = false
    @State private var devAssets: [DevMediaAsset] = []
    @State private var selectedDevAssetIDs: [DevMediaAsset.ID] = []
    @State private var devErrorMessage: String?
    @State private var isResolving = false
    @State private var isPhotoPermissionAlertPresented = false
    @State private var scrollProgress: Double = 0
    @State private var titleInput: String = ""
    @FocusState private var isTitleFocused: Bool

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
        .onChange(of: selectedAssetIDs) { _, newIDs in
            syncMedia(for: newIDs)
        }
        .task {
            await loadDevAssetsIfNeeded()
            await refreshPhotoLibraryIfAuthorized()
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
                handlePrimaryAction()
            } label: {
                if isResolving || isPreparingPhotoLibraryMedia {
                    ProgressView().controlSize(.small).tint(MomentsColor.coral)
                } else {
                    Text("다음")
                        .font(MomentsTypography.krSemibold(14))
                        .foregroundColor(canUsePrimaryAction ? MomentsColor.ink : MomentsColor.taupe.opacity(0.5))
                }
            }
            .buttonStyle(.momentsHeaderPrimaryAction)
            .accessibilityLabel(isResolving || isPreparingPhotoLibraryMedia ? "미디어 준비 중" : "다음")
            .accessibilityHint(confirmAccessibilityHint)
            .disabled(!canUsePrimaryAction || isResolving)
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
            handlePhotoLibraryLauncher()
        } label: {
            HStack(spacing: MomentsSpacing.sm) {
                MomentsIcon(.plus, size: 18)
                    .foregroundColor(MomentsColor.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text(photoLibraryLauncherTitle)
                        .font(MomentsTypography.krSemibold(15))
                        .foregroundColor(MomentsColor.ink)
                    Text(photoLibraryLauncherSubtitle)
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
                                  style: .init(lineWidth: 1.2, dash: selectedAssetIDs.isEmpty ? [5, 3] : []))
            )
        }
        .buttonStyle(.plain)
        .disabled(isPhotoLibraryLoading)
        .accessibilityLabel(photoLibraryLauncherTitle)
        .accessibilityHint("사진 권한 범위 안의 Live Photo와 영상을 불러옵니다.")
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
        VStack(alignment: .leading, spacing: MomentsSpacing.sm) {
            HStack(spacing: MomentsSpacing.xs) {
                Text("권한 사진 · \(photoAssets.count)")
                    .tagLabel()
                Spacer()
                if selectedLiveCount > 0 {
                    MomentsChip("\(selectedLiveCount) LIVE", variant: .live)
                }
                if selectedVideoCount > 0 {
                    MomentsChip("\(selectedVideoCount) VIDEO", variant: .video, icon: .film)
                }
            }

            if let photoLibraryStatusMessage {
                HStack(spacing: MomentsSpacing.xs) {
                    if isPreparingPhotoLibraryMedia || isPhotoLibraryLoading {
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

            if photoAssets.isEmpty {
                HandNoteRow(photoLibraryEmptyMessage,
                            tone: .muted, size: 17, alignment: .leading)
                    .padding(.vertical, MomentsSpacing.lg)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: MomentsSpacing.sm), count: 3),
                    spacing: MomentsSpacing.sm
                ) {
                    ForEach(Array(photoAssets.enumerated()), id: \.element.id) { idx, asset in
                        let isSelected = selectedAssetIDs.contains(asset.id)
                        Button {
                            dismissTitleKeyboard()
                            togglePhotoAsset(asset)
                        } label: {
                            ClipThumbCard(
                                state: isSelected ? .selected : .normal,
                                rotationDegrees: rotation(for: idx),
                                size: CGSize(width: 84, height: 108)
                            ) {
                                thumbnailContent(for: asset)
                            }
                            .overlay(alignment: .topLeading) {
                                floatingKindChip(for: asset.kind)
                            }
                            .overlay(alignment: .topTrailing) {
                                if isSelected {
                                    Circle()
                                        .fill(MomentsColor.coral)
                                        .frame(width: 22, height: 22)
                                        .overlay(MomentsIcon(.check, size: 10).foregroundColor(.white))
                                        .padding(2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(thumbnailAccessibilityLabel(for: asset, index: idx, isSelected: isSelected))
                        .accessibilityHint(isSelected ? "선택됨. 두 번 탭하면 선택을 해제합니다." : "두 번 탭하면 선택합니다.")
                    }
                }
                .padding(.top, MomentsSpacing.md)
                .padding(.bottom, MomentsSpacing.sm)
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
    private func thumbnailContent(for asset: PhotoLibraryAsset) -> some View {
        let state = media[asset.id] ?? MediaLoadState(kind: asset.kind)
        ZStack {
            let thumbnail = state.thumbnail ?? assetThumbnails[asset.id]
            if let data = thumbnail, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if state.thumbnailFailed {
                failedPlaceholder
            } else {
                MomentsColor.ivory
                ProgressView()
                    .tint(MomentsColor.coral)
            }

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
        .task(id: asset.id) {
            await loadThumbnailIfNeeded(for: asset)
        }
    }

    @ViewBuilder
    private func floatingKindChip(for kind: MediaKind) -> some View {
        kindChip(for: kind)
            .fixedSize(horizontal: true, vertical: true)
            .offset(x: -5, y: -7)
            .allowsHitTesting(false)
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
                    handlePrimaryAction()
                } label: {
                    confirmBottomLabel
                        .foregroundStyle(MomentsColor.ink)
                        .frame(maxWidth: .infinity, minHeight: MomentsSpacing.minimumHitTarget)
                }
                .buttonStyle(.glassProminent)
                .tint(MomentsColor.coral)
                .frame(maxWidth: .infinity)
                .disabled(!canUsePrimaryAction || isResolving)
                .opacity(canUsePrimaryAction ? 1 : 0.5)
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
                handlePrimaryAction()
            } label: {
                confirmBottomLabel
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.momentsCoral)
            .frame(maxWidth: .infinity)
            .disabled(!canUsePrimaryAction || isResolving)
            .opacity(canUsePrimaryAction ? 1 : 0.5)
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
            return !selectedAssetIDs.isEmpty && selectedAssetIDs.allSatisfy { id in
                media[id]?.isReadyForTimeline == true
            }
        case .devFixtures:
            return !selectedDevAssetIDs.isEmpty
        }
    }

    private var canUsePrimaryAction: Bool {
        canProceed
    }

    private var isPreparingPhotoLibraryMedia: Bool {
        guard case .photoLibrary = source, !selectedAssetIDs.isEmpty else { return false }
        return !canProceed && !hasUnavailablePhotoLibraryMedia
    }

    private var hasUnavailablePhotoLibraryMedia: Bool {
        guard case .photoLibrary = source else { return false }
        return selectedAssetIDs.contains { id in
            media[id]?.didFailTimelinePreparation == true
        }
    }

    private var hasPhotoAccess: Bool {
        photoAuthorizationStatus == .authorized || photoAuthorizationStatus == .limited
    }

    private var isLimitedPhotoAccess: Bool {
        photoAuthorizationStatus == .limited
    }

    private var readyPhotoLibraryMediaCount: Int {
        selectedAssetIDs.reduce(into: 0) { count, id in
            if media[id]?.isReadyForTimeline == true {
                count += 1
            }
        }
    }

    private var photoLibraryStatusMessage: String? {
        guard case .photoLibrary = source else { return nil }
        if photoAuthorizationStatus == .denied || photoAuthorizationStatus == .restricted {
            return "사진 권한을 허용해야 Live Photo 영상을 사용할 수 있어요."
        }
        if photoAuthorizationStatus == .notDetermined {
            return "먼저 사진 권한 범위를 선택해 주세요."
        }
        if isPhotoLibraryLoading {
            return "권한 사진을 불러오는 중"
        }
        if photoAssets.isEmpty {
            return isLimitedPhotoAccess ? "권한 목록에 Live Photo나 영상이 없어요." : "보관함에 Live Photo나 영상이 없어요."
        }
        if hasUnavailablePhotoLibraryMedia {
            return "선택한 항목을 불러오지 못했어요. 다시 선택해 주세요."
        }
        if !selectedAssetIDs.isEmpty, readyPhotoLibraryMediaCount < selectedAssetIDs.count {
            return "사진 로딩 중 · \(readyPhotoLibraryMediaCount)/\(selectedAssetIDs.count)"
        }
        return nil
    }

    private var photoLibraryStatusColor: Color {
        if hasUnavailablePhotoLibraryMedia || photoAuthorizationStatus == .denied || photoAuthorizationStatus == .restricted {
            return MomentsColor.coral
        }
        return MomentsColor.taupe
    }

    private var confirmButtonTitle: String {
        if selectedCount == 0 {
            return "선택 후 다음"
        }
        if case .photoLibrary = source {
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
            if selectedAssetIDs.isEmpty {
                return "미디어를 선택하면 다음 단계로 이동할 수 있습니다."
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
            return selectedAssetIDs.count
        case .devFixtures:
            return selectedDevAssetIDs.count
        }
    }

    private func dismissTitleKeyboard() {
        isTitleFocused = false
    }

    private var photoLibraryLauncherTitle: String {
        if photoAuthorizationStatus == .notDetermined {
            return "사진 권한 선택"
        }
        if photoAuthorizationStatus == .denied || photoAuthorizationStatus == .restricted {
            return "사진 권한 열기"
        }
        if isLimitedPhotoAccess {
            return "권한 사진 추가/새로고침"
        }
        return "사진 보관함 새로고침"
    }

    private var photoLibraryLauncherSubtitle: String {
        if photoAuthorizationStatus == .notDetermined {
            return "먼저 권한 범위를 고른 뒤 선택해요"
        }
        if photoAuthorizationStatus == .denied || photoAuthorizationStatus == .restricted {
            return "설정에서 사진 접근을 허용해 주세요"
        }
        if isPhotoLibraryLoading {
            return "권한 사진을 불러오는 중"
        }
        if isLimitedPhotoAccess {
            return "\(photoAssets.count)개 접근 가능 · \(selectedAssetIDs.count)개 선택됨"
        }
        return "\(photoAssets.count)개 접근 가능 · \(selectedAssetIDs.count)개 선택됨"
    }

    private var photoLibraryEmptyMessage: String {
        if photoAuthorizationStatus == .notDetermined {
            return "먼저 사진 권한 범위를 선택해 주세요 ✦"
        }
        if photoAuthorizationStatus == .denied || photoAuthorizationStatus == .restricted {
            return "사진 권한을 허용해야 Live Photo 영상을 만들 수 있어요 ✦"
        }
        if isPhotoLibraryLoading {
            return "권한 사진을 불러오고 있어요 ✦"
        }
        if isLimitedPhotoAccess {
            return "권한 목록에 Live Photo나 영상이 없어요. 권한 사진을 추가해 주세요 ✦"
        }
        return "보관함에 Live Photo나 영상이 없어요 ✦"
    }

    private var selectedLiveCount: Int {
        selectedAssetIDs.reduce(into: 0) { acc, id in
            if media[id]?.kind == .livePhoto {
                acc += 1
            }
        }
    }

    private var selectedVideoCount: Int {
        selectedAssetIDs.reduce(into: 0) { acc, id in
            if media[id]?.kind == .video {
                acc += 1
            }
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

    private func thumbnailAccessibilityLabel(
        for asset: PhotoLibraryAsset,
        index: Int,
        isSelected: Bool
    ) -> String {
        let state = media[asset.id] ?? MediaLoadState(kind: asset.kind)
        var parts = ["\(index + 1)번째 권한 미디어", accessibilityLabel(for: asset.kind)]
        if isSelected {
            parts.append("선택됨")
            if !state.isFullyLoaded {
                parts.append("불러오는 중")
            }
            if state.thumbnailFailed {
                parts.append("썸네일 불러오기 실패")
            }
            if state.videoFailed {
                parts.append("영상 추출 실패")
            }
        } else if assetThumbnails[asset.id] == nil {
            parts.append("썸네일 불러오는 중")
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

    private func handlePhotoLibraryLauncher() {
        dismissTitleKeyboard()
        Task {
            if isLimitedPhotoAccess {
                await MainActor.run {
                    openLimitedPhotoLibraryPicker()
                }
            } else {
                await preparePhotoLibraryAccess()
            }
        }
    }

    @MainActor
    private func refreshPhotoLibraryIfAuthorized() async {
        photoAuthorizationStatus = Self.currentPhotoAuthorizationStatus
        guard hasPhotoAccess else { return }
        await loadAuthorizedPhotoAssets()
    }

    @MainActor
    private func preparePhotoLibraryAccess() async {
        switch Self.currentPhotoAuthorizationStatus {
        case .authorized, .limited:
            photoAuthorizationStatus = Self.currentPhotoAuthorizationStatus
            await loadAuthorizedPhotoAssets()
        case .notDetermined:
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            photoAuthorizationStatus = status
            if status == .authorized || status == .limited {
                await loadAuthorizedPhotoAssets()
            } else {
                isPhotoPermissionAlertPresented = true
            }
        default:
            photoAuthorizationStatus = Self.currentPhotoAuthorizationStatus
            isPhotoPermissionAlertPresented = true
        }
    }

    @MainActor
    private func loadAuthorizedPhotoAssets() async {
        isPhotoLibraryLoading = true
        let assets = await Self.fetchAuthorizedPhotoAssets()
        photoAssets = assets

        let validIDs = Set(assets.map(\.id))
        selectedAssetIDs.removeAll { !validIDs.contains($0) }
        media = media.filter { validIDs.contains($0.key) }
        assetThumbnails = assetThumbnails.filter { validIDs.contains($0.key) }
        syncMedia(for: selectedAssetIDs)
        isPhotoLibraryLoading = false
    }

    private func togglePhotoAsset(_ asset: PhotoLibraryAsset) {
        if let index = selectedAssetIDs.firstIndex(of: asset.id) {
            selectedAssetIDs.remove(at: index)
        } else {
            selectedAssetIDs.append(asset.id)
        }
    }

    private func syncMedia(for newIDs: [String]) {
        let retained = Set(newIDs)
        media = media.filter { retained.contains($0.key) }

        for id in newIDs where media[id] == nil {
            let asset = photoAssets.first { $0.id == id }
            let initialKind = asset?.kind ?? .unknown
            media[id] = MediaLoadState(kind: initialKind, thumbnail: assetThumbnails[id], isLoading: true)

            Task {
                async let thumbnail: Data? = Self.loadThumbnail(forAssetID: id)
                async let videoURLTask: URL? = Self.loadVideoURL(forAssetID: id, kind: initialKind)
                async let capturedAt: Date? = Self.loadCapturedAt(forAssetID: id)

                // duration·displaySize 는 videoURL 이 결정된 뒤에야 읽을 수 있어 직렬 의존.
                let url = await videoURLTask
                async let durTask: TimeInterval? = Self.loadVideoDuration(from: url)
                async let sizeTask: CGSize? = Self.loadDisplaySize(from: url)
                let (loadedThumb, captured, dur, size) = await (thumbnail, capturedAt, durTask, sizeTask)

                await MainActor.run {
                    guard var state = media[id] else { return }
                    let thumb = loadedThumb ?? assetThumbnails[id]
                    state.thumbnail = thumb
                    if let thumb {
                        assetThumbnails[id] = thumb
                    }
                    state.thumbnailFailed = (thumb == nil)
                    state.videoURL = url
                    state.videoFailed = (url == nil)
                    state.duration = dur
                    state.capturedAt = captured
                    state.displaySize = size
                    state.isLoading = false
                    media[id] = state
                }
            }
        }
    }

    @MainActor
    private func loadThumbnailIfNeeded(for asset: PhotoLibraryAsset) async {
        guard assetThumbnails[asset.id] == nil else { return }
        guard let data = await Self.loadThumbnail(forAssetID: asset.id) else { return }
        assetThumbnails[asset.id] = data
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

    // MARK: - PhotoKit loading

    private static var currentPhotoAuthorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    private static func fetchAuthorizedPhotoAssets() async -> [PhotoLibraryAsset] {
        await Task.detached(priority: .userInitiated) {
            var assets: [PhotoLibraryAsset] = []

            let liveOptions = PHFetchOptions()
            liveOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let liveFetch = PHAsset.fetchAssets(with: .image, options: liveOptions)
            liveFetch.enumerateObjects { asset, _, _ in
                guard asset.mediaSubtypes.contains(.photoLive) else { return }
                assets.append(PhotoLibraryAsset(asset: asset, kind: .livePhoto))
            }

            let videoOptions = PHFetchOptions()
            videoOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let videoFetch = PHAsset.fetchAssets(with: .video, options: videoOptions)
            videoFetch.enumerateObjects { asset, _, _ in
                assets.append(PhotoLibraryAsset(asset: asset, kind: .video))
            }

            return assets.sorted { lhs, rhs in
                (lhs.capturedAt ?? .distantPast) > (rhs.capturedAt ?? .distantPast)
            }
        }.value
    }

    private static func fetchAsset(with localID: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil).firstObject
    }

    private static func loadCapturedAt(forAssetID localID: String) async -> Date? {
        fetchAsset(with: localID)?.creationDate
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

    // MARK: - Thumbnail

    private static func loadThumbnail(forAssetID localID: String) async -> Data? {
        guard let asset = fetchAsset(with: localID) else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            final class ResumeBox {
                var didResume = false
            }
            let box = ResumeBox()
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 480, height: 620),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !box.didResume else { return }
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true {
                    return
                }
                box.didResume = true
                continuation.resume(returning: image?.jpegData(compressionQuality: 0.75))
            }
        }
    }

    // MARK: - Video URL

    private static func loadVideoURL(forAssetID localID: String, kind: MediaKind) async -> URL? {
        guard kind.hasMotion else {
            return nil
        }
        return await loadViaPHAsset(localID: localID)
    }

    /// 기존 사진 읽기 권한이 있을 때만 paired video / 원본 영상을 temp 파일로 내림.
    private static func loadViaPHAsset(localID: String) async -> URL? {
        mediaLogger.debug("loadViaPHAsset start")
        guard let asset = fetchAsset(with: localID) else {
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

    private func openLimitedPhotoLibraryPicker() {
        guard let presenter = Self.activeViewController else {
            openPhotoSettings()
            return
        }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presenter) { _ in
            Task { @MainActor in
                await refreshPhotoLibraryIfAuthorized()
            }
        }
    }

    private static var activeViewController: UIViewController? {
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let root = activeScene?.windows.first { $0.isKeyWindow }?.rootViewController
        var presenter = root
        while let presented = presenter?.presentedViewController {
            presenter = presented
        }
        return presenter
    }

    // MARK: - Confirm

    private func handlePrimaryAction() {
        dismissTitleKeyboard()
        confirmSelection()
    }

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

        let ids = selectedAssetIDs

        Task {
            let latest = await MainActor.run { self.media }
            guard ids.allSatisfy({ latest[$0]?.isReadyForTimeline == true }) else {
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

            let clips: [Clip] = ids.enumerated().map { idx, id in
                let state = latest[id] ?? MediaLoadState()
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

private struct PhotoLibraryAsset: Identifiable, Hashable {
    let id: String
    let kind: MediaKind
    let capturedAt: Date?
    let pixelSize: CGSize

    init(asset: PHAsset, kind: MediaKind) {
        self.id = asset.localIdentifier
        self.kind = kind
        self.capturedAt = asset.creationDate
        self.pixelSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
    }
}

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
