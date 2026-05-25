import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem
import PhotosService
import Photos
import PhotosUI
import UIKit

/// Live Photo + 영상을 선택해 Timeline 으로 넘기는 화면. TCA store 기반.
public struct MediaPickerView: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppRouter.self) private var router
    @Environment(EditSession.self) private var session

    @Bindable var store: StoreOf<MediaPickerFeature>
    @FocusState private var isTitleFocused: Bool

    public init(store: StoreOf<MediaPickerFeature>) {
        self.store = store
    }

    /// 기존 호출 호환용 편의 init.
    public init(source: MediaPickerSource = .photoLibrary) {
        self.store = Store(initialState: MediaPickerFeature.State(source: source)) {
            MediaPickerFeature()
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            header.momentsHeaderBar(scrollProgress: store.scrollProgress)
                .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })
                .zIndex(1)

            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        intro
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .trackScrollOffset(in: "media-picker-scroll")
                            .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })

                        titleField
                            .padding(.horizontal, 24)

                        pickerLauncher
                            .padding(.horizontal, 24)
                            .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })

                        selectionGrid
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                            .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })
                    }
                    .padding(.bottom, 96)
                }
                .coordinateSpace(name: "media-picker-scroll")
                .scrollDismissesKeyboard(.interactively)
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { dismissTitleKeyboard() }
                )
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    store.send(
                        .scrollProgressChanged(offset / 8),
                        animation: .easeInOut(duration: 0.15)
                    )
                }

                bottomActionArea
                    .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })
            }
        }
        .momentsScreen()
        .alert(
            "Live Photo 권한이 필요해요",
            isPresented: $store.isPhotoPermissionAlertPresented.sending(\.permissionAlertPresentedChanged),
            actions: {
                Button("확인") {
                    store.send(.permissionAlertConfirmTapped)
                    openPhotoSettings()
                }
            },
            message: {
                Text("Live Photo를 영상으로 사용하려면 사진 보관함 접근 권한이 필요해요.")
            }
        )
        .onChange(of: store.confirmation?.id) { _, newID in
            guard newID != nil, let confirmation = store.confirmation else { return }
            session.replace(clips: confirmation.clips, title: confirmation.title)
            router.push(.timeline)
        }
        .sheet(
            isPresented: $store.isSystemPhotoPickerPresented.sending(\.systemPhotoPickerPresentedChanged)
        ) {
            SystemPhotoPicker { identifiers in
                store.send(.photosPickedFromSystemPicker(identifiers: identifiers))
            }
            .ignoresSafeArea()
        }
        .task { await store.send(.task).finish() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismissTitleKeyboard()
                store.send(.dismissTapped)
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
                store.send(.primaryActionTapped)
            } label: {
                if store.isResolving || isPreparingMedia {
                    ProgressView().controlSize(.small).tint(MomentsColor.coral)
                } else {
                    Text("다음")
                        .font(MomentsTypography.krSemibold(14))
                        .foregroundColor(canUsePrimaryAction ? MomentsColor.ink : MomentsColor.taupe.opacity(0.5))
                }
            }
            .buttonStyle(.momentsHeaderPrimaryAction)
            .accessibilityLabel(store.isResolving || isPreparingMedia ? "미디어 준비 중" : "다음")
            .disabled(!canUsePrimaryAction || store.isResolving)
        }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PICK · YOUR MOMENTS").tagLabel()
            (Text("여행의 순간을\n").font(MomentsTypography.displayKR(26))
             + Text("천천히 골라보세요.").font(MomentsTypography.krBody(22, weight: .medium)))
                .foregroundColor(MomentsColor.ink)
                .lineSpacing(2)
            Text("Live Photo와 짧은 영상을 불러올 수 있어요. Live Photo는 내부의 영상 부분을 사용합니다.")
                .font(MomentsTypography.krBody(13))
                .foregroundColor(MomentsColor.taupe)
                .padding(.top, 4)
        }
    }

    // MARK: - Title field

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TITLE · 이번 필름의 제목").tagLabel()

            TextField(
                "",
                text: $store.titleInput.sending(\.titleChanged),
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
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
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
        switch store.source {
        case .photoLibrary: photoLauncher
        case .devFixtures:  devLauncher
        }
    }

    private var photoLauncher: some View {
        Button {
            dismissTitleKeyboard()
            store.send(.photoLauncherTapped)
        } label: {
            HStack(spacing: 12) {
                MomentsIcon(.plus, size: 18).foregroundColor(MomentsColor.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text(photoLauncherTitle)
                        .font(MomentsTypography.krSemibold(15))
                        .foregroundColor(MomentsColor.ink)
                    Text(photoLauncherSubtitle)
                        .font(MomentsTypography.krBody(12))
                        .foregroundColor(MomentsColor.taupe)
                }
                Spacer()
                MomentsIcon(.chevronRight, size: 14).foregroundColor(MomentsColor.taupe)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .strokeBorder(MomentsColor.coral.opacity(0.5),
                                  style: .init(lineWidth: 1.2,
                                               dash: store.selectedAssetIDs.isEmpty ? [5, 3] : []))
            )
        }
        .buttonStyle(.plain)
        .disabled(store.isPhotoLibraryLoading)
        .accessibilityLabel(photoLauncherTitle)
    }

    private var devLauncher: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                MomentsIcon(.film, size: 18).foregroundColor(MomentsColor.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dev 미디어 소스")
                        .font(MomentsTypography.krSemibold(15))
                        .foregroundColor(MomentsColor.ink)
                    Text(store.selectedDevAssetIDs.isEmpty
                         ? "번들 fixture로 실제 export까지 확인"
                         : "\(store.selectedDevAssetIDs.count)개 fixture 선택됨")
                        .font(MomentsTypography.krBody(12))
                        .foregroundColor(MomentsColor.taupe)
                }
                Spacer()
                MomentsChip("DEV", variant: .dashed)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                    .strokeBorder(MomentsColor.coral.opacity(0.45), lineWidth: 1.2)
            )

            if let devErrorMessage = store.devErrorMessage {
                Text(devErrorMessage)
                    .font(MomentsTypography.krBody(12))
                    .foregroundColor(MomentsColor.coral)
            }
        }
    }

    // MARK: - Selection grid

    @ViewBuilder
    private var selectionGrid: some View {
        switch store.source {
        case .photoLibrary: photoGrid
        case .devFixtures:  devGrid
        }
    }

    @ViewBuilder
    private var photoGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("선택한 미디어 · \(selectedAssets.count)").tagLabel()
                Spacer()
                if selectedLiveCount > 0 {
                    MomentsChip("\(selectedLiveCount) LIVE", variant: .live)
                }
                if selectedVideoCount > 0 {
                    MomentsChip("\(selectedVideoCount) VIDEO", variant: .video, icon: .film)
                }
            }

            if let statusMessage = photoStatusMessage {
                HStack(spacing: 8) {
                    if isPreparingMedia || store.isPhotoLibraryLoading {
                        ProgressView().controlSize(.small).tint(MomentsColor.coral)
                    } else {
                        MomentsIcon(.download, size: 12)
                    }
                    Text(statusMessage)
                        .font(MomentsTypography.krBody(12, weight: .medium))
                }
                .foregroundColor(photoStatusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                        .fill(MomentsColor.ivory.opacity(0.75))
                )
            }

            if selectedAssets.isEmpty {
                Text(photoEmptyMessage)
                    .font(MomentsTypography.krBody(MomentsTypography.Size.body))
                    .foregroundColor(MomentsColor.taupe)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                    spacing: 12
                ) {
                    ForEach(Array(selectedAssets.enumerated()), id: \.element.id) { idx, asset in
                        Button {
                            dismissTitleKeyboard()
                            store.send(.photoAssetTapped(asset))
                        } label: {
                            ClipThumbCard(
                                state: .selected,
                                size: CGSize(width: 84, height: 108)
                            ) {
                                photoThumbnail(for: asset)
                            }
                            .overlay(alignment: .topLeading) {
                                kindChip(for: asset.kind)
                                    .scaleEffect(0.78, anchor: .topLeading)
                                    .fixedSize(horizontal: true, vertical: true)
                                    .offset(x: -5, y: -7)
                                    .allowsHitTesting(false)
                            }
                            .overlay(alignment: .topTrailing) {
                                Circle()
                                    .fill(MomentsColor.coral)
                                    .frame(width: 22, height: 22)
                                    .overlay(MomentsIcon(.close, size: 10).foregroundColor(.white))
                                    .padding(2)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(thumbnailAccessibilityLabel(for: asset, index: idx, isSelected: true))
                        .accessibilityHint("탭하면 선택에서 제외돼요")
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private var devGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("DEV FIXTURES · \(store.selectedDevAssetIDs.count)").tagLabel()
                Spacer()
                if devLiveCount > 0 {
                    MomentsChip("\(devLiveCount) LIVE", variant: .live)
                }
                if devVideoCount > 0 {
                    MomentsChip("\(devVideoCount) VIDEO", variant: .video, icon: .film)
                }
            }

            if store.devAssets.isEmpty {
                Text("Dev 미디어를 준비하고 있어요")
                    .font(MomentsTypography.krBody(MomentsTypography.Size.body))
                    .foregroundColor(MomentsColor.taupe)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                    spacing: 16
                ) {
                    ForEach(store.devAssets) { asset in
                        let isSelected = store.selectedDevAssetIDs.contains(asset.id)
                        Button {
                            dismissTitleKeyboard()
                            store.send(.devAssetTapped(asset.id))
                        } label: {
                            DevMediaAssetCard(asset: asset, isSelected: isSelected)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(asset.title), \(asset.kind == .live ? "라이브 포토" : "비디오")")
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private func photoThumbnail(for asset: PhotoLibraryAsset) -> some View {
        let state = store.media[asset.id] ?? MediaLoadState(kind: asset.kind)
        ZStack {
            let thumbnail = state.thumbnail ?? store.assetThumbnails[asset.id]
            if let data = thumbnail, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if state.thumbnailFailed {
                ZStack {
                    MomentsColor.ivory
                    MomentsIcon(.close, size: 14).foregroundColor(MomentsColor.taupe)
                }
            } else {
                MomentsColor.ivory
                ProgressView().tint(MomentsColor.coral)
            }

            if state.kind == .video {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 22, height: 22)
                    .overlay(MomentsIcon(.play, size: 9).foregroundColor(MomentsColor.ink).offset(x: 1))
            }

            if state.videoFailed && state.thumbnail != nil {
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
    private func kindChip(for kind: PhotoLibraryAssetKind) -> some View {
        switch kind {
        case .livePhoto: MomentsChip("LIVE", variant: .live)
        case .video:     MomentsChip("VIDEO", variant: .video, icon: .film)
        case .image, .unknown: EmptyView()
        }
    }

    // MARK: - Bottom bar

    private var bottomActionArea: some View {
        bottomBar
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
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
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    dismissTitleKeyboard()
                    store.send(.dismissTapped)
                    router.pop()
                } label: {
                    Text("취소")
                        .foregroundStyle(MomentsColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)

                Button {
                    store.send(.primaryActionTapped)
                } label: {
                    confirmBottomLabel
                        .foregroundStyle(MomentsColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(MomentsColor.coral)
                .frame(maxWidth: .infinity)
                .disabled(!canUsePrimaryAction || store.isResolving)
                .opacity(canUsePrimaryAction ? 1 : 0.5)
            }
        }
    }

    private var momentsBottomBar: some View {
        HStack(spacing: 8) {
            Button {
                dismissTitleKeyboard()
                store.send(.dismissTapped)
                router.pop()
            } label: {
                Text("취소").frame(maxWidth: .infinity)
            }
            .buttonStyle(.momentsOutline)
            .frame(maxWidth: .infinity)

            Button {
                store.send(.primaryActionTapped)
            } label: {
                confirmBottomLabel.frame(maxWidth: .infinity)
            }
            .buttonStyle(.momentsCoral)
            .frame(maxWidth: .infinity)
            .disabled(!canUsePrimaryAction || store.isResolving)
            .opacity(canUsePrimaryAction ? 1 : 0.5)
        }
    }

    private var confirmBottomLabel: some View {
        HStack(spacing: 6) {
            if store.isResolving || isPreparingMedia {
                ProgressView().controlSize(.small).tint(MomentsColor.ink)
            } else {
                MomentsIcon(.check, size: 14)
            }
            Text(confirmButtonTitle)
        }
    }

    // MARK: - Derived

    private var canProceed: Bool {
        switch store.source {
        case .photoLibrary:
            return !store.selectedAssetIDs.isEmpty
                && store.selectedAssetIDs.allSatisfy { store.media[$0]?.isReadyForTimeline == true }
        case .devFixtures:
            return !store.selectedDevAssetIDs.isEmpty
        }
    }

    private var canUsePrimaryAction: Bool { canProceed }

    private var isPreparingMedia: Bool {
        guard case .photoLibrary = store.source, !store.selectedAssetIDs.isEmpty else { return false }
        return !canProceed && !hasUnavailableMedia
    }

    private var hasUnavailableMedia: Bool {
        guard case .photoLibrary = store.source else { return false }
        return store.selectedAssetIDs.contains { id in
            store.media[id]?.didFailTimelinePreparation == true
        }
    }

    private var selectedAssets: [PhotoLibraryAsset] {
        store.selectedAssetIDs.compactMap { id in
            store.photoAssets.first(where: { $0.id == id })
        }
    }

    private var readyMediaCount: Int {
        store.selectedAssetIDs.reduce(into: 0) { count, id in
            if store.media[id]?.isReadyForTimeline == true {
                count += 1
            }
        }
    }

    private var photoStatusMessage: String? {
        guard case .photoLibrary = store.source else { return nil }
        let status = store.photoAuthorizationStatus
        if status == .denied || status == .restricted {
            return "사진 권한을 허용해야 Live Photo 영상을 사용할 수 있어요."
        }
        if status == .notDetermined {
            return "먼저 사진 권한 범위를 선택해 주세요."
        }
        if store.isPhotoLibraryLoading {
            return "선택한 사진을 불러오는 중"
        }
        if hasUnavailableMedia {
            return "선택한 항목을 불러오지 못했어요. 다시 선택해 주세요."
        }
        if !store.selectedAssetIDs.isEmpty, readyMediaCount < store.selectedAssetIDs.count {
            return "사진 로딩 중 · \(readyMediaCount)/\(store.selectedAssetIDs.count)"
        }
        return nil
    }

    private var photoStatusColor: Color {
        if hasUnavailableMedia || store.photoAuthorizationStatus == .denied || store.photoAuthorizationStatus == .restricted {
            return MomentsColor.coral
        }
        return MomentsColor.taupe
    }

    private var confirmButtonTitle: String {
        if selectedCount == 0 {
            return "선택 후 다음"
        }
        if case .photoLibrary = store.source {
            if hasUnavailableMedia { return "원본 확인 필요" }
            if !canProceed { return "사진 로딩 중" }
        }
        return "Timeline으로 (\(selectedCount))"
    }

    private var selectedCount: Int {
        switch store.source {
        case .photoLibrary: return store.selectedAssetIDs.count
        case .devFixtures:  return store.selectedDevAssetIDs.count
        }
    }

    private var photoLauncherTitle: String {
        let status = store.photoAuthorizationStatus
        if status == .notDetermined { return "사진 권한 선택" }
        if status == .denied || status == .restricted { return "사진 권한 열기" }
        return store.selectedAssetIDs.isEmpty ? "사진 추가하기" : "다시 고르기"
    }

    private var photoLauncherSubtitle: String {
        let status = store.photoAuthorizationStatus
        if status == .notDetermined { return "먼저 권한 범위를 고른 뒤 선택해요" }
        if status == .denied || status == .restricted { return "설정에서 사진 접근을 허용해 주세요" }
        if store.isPhotoLibraryLoading { return "선택한 사진을 불러오는 중" }
        if store.selectedAssetIDs.isEmpty { return "Live Photo와 짧은 영상만 가져올 수 있어요" }
        return "\(store.selectedAssetIDs.count)개 선택됨 · 탭해서 추가해요"
    }

    private var photoEmptyMessage: String {
        let status = store.photoAuthorizationStatus
        if status == .notDetermined { return "먼저 사진 권한 범위를 선택해 주세요" }
        if status == .denied || status == .restricted { return "사진 권한을 허용해야 Live Photo 영상을 만들 수 있어요" }
        if store.isPhotoLibraryLoading { return "선택한 사진을 불러오고 있어요" }
        return "아직 선택한 사진이 없어요. 위 카드를 눌러 골라보세요."
    }

    private var selectedLiveCount: Int {
        store.selectedAssetIDs.reduce(into: 0) { acc, id in
            if store.media[id]?.kind == .livePhoto { acc += 1 }
        }
    }

    private var selectedVideoCount: Int {
        store.selectedAssetIDs.reduce(into: 0) { acc, id in
            if store.media[id]?.kind == .video { acc += 1 }
        }
    }

    private var devLiveCount: Int {
        store.devAssets.reduce(into: 0) { acc, asset in
            if store.selectedDevAssetIDs.contains(asset.id), asset.kind == .live { acc += 1 }
        }
    }

    private var devVideoCount: Int {
        store.devAssets.reduce(into: 0) { acc, asset in
            if store.selectedDevAssetIDs.contains(asset.id), asset.kind == .video { acc += 1 }
        }
    }

    private func thumbnailAccessibilityLabel(
        for asset: PhotoLibraryAsset,
        index: Int,
        isSelected: Bool
    ) -> String {
        let state = store.media[asset.id] ?? MediaLoadState(kind: asset.kind)
        let kindLabel: String = {
            switch asset.kind {
            case .video: return "비디오"
            case .livePhoto: return "라이브 포토"
            case .image: return "사진"
            case .unknown: return "종류 확인 중"
            }
        }()
        var parts = ["\(index + 1)번째 선택한 미디어", kindLabel]
        if isSelected {
            if !state.isFullyLoaded { parts.append("불러오는 중") }
            if state.thumbnailFailed { parts.append("썸네일 불러오기 실패") }
            if state.videoFailed { parts.append("영상 추출 실패") }
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Side effects

    private func dismissTitleKeyboard() {
        isTitleFocused = false
    }

    private func openPhotoSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }
}

// MARK: - SystemPhotoPicker

/// PHPickerViewController 를 SwiftUI sheet 로 띄우기 위한 래퍼.
/// Live Photo 와 영상만 노출하고, 결과는 PHAsset.localIdentifier 배열로 돌려준다.
private struct SystemPhotoPicker: UIViewControllerRepresentable {
    let onPicked: ([String]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .any(of: [.livePhotos, .videos])
        config.selectionLimit = 0   // 무제한
        config.preferredAssetRepresentationMode = .current
        let controller = PHPickerViewController(configuration: config)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: ([String]) -> Void
        init(onPicked: @escaping ([String]) -> Void) { self.onPicked = onPicked }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let ids = results.compactMap(\.assetIdentifier)
            picker.dismiss(animated: true) { [onPicked] in
                onPicked(ids)
            }
        }
    }
}

// MARK: - DevMediaAssetCard

private struct DevMediaAssetCard: View {
    let asset: DevMediaAsset
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ClipThumbCard(
                state: isSelected ? .selected : .normal,
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
                Text(asset.locationNote ?? String(format: "%.1fs", asset.duration))
                    .font(MomentsTypography.krBody(11))
                    .foregroundColor(MomentsColor.taupe)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
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
        case .live:  MomentsChip("LIVE", variant: .live).scaleEffect(0.72, anchor: .topLeading)
        case .video: MomentsChip("VIDEO", variant: .video, icon: .film).scaleEffect(0.72, anchor: .topLeading)
        }
    }
}

#Preview("MediaPicker — empty") {
    MediaPickerView(source: .photoLibrary)
        .environment(AppRouter())
        .environment(EditSession())
}

#Preview("MediaPicker — Dev") {
    MediaPickerView(source: .devFixtures(BundledDevMediaSource()))
        .environment(AppRouter())
        .environment(EditSession())
}
