import SwiftUI
import ComposableArchitecture
import Models
import DesignSystem
import PhotosService
import Photos
import PhotosUI
import UIKit

/// Live Photo + 영상을 선택해 Timeline 으로 넘기는 화면. TCA store 기반.
public struct MediaPickerView: View {
    @Environment(\.openURL) private var openURL

    @Bindable var store: StoreOf<MediaPickerFeature>

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
            header
                .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })
                .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                        .trackScrollOffset(in: "media-picker-scroll")
                        .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })

                    pickerLauncher
                        .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })

                    selectionGrid
                        .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })

                    // 제목은 고른 뒤에 붙인다. 선택이 0개면 물을 이유가 없다.
                    if selectedCount > 0 {
                        titleField
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
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
        .chalNaScreen()
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
        .sheet(
            isPresented: $store.isSystemPhotoPickerPresented.sending(\.systemPhotoPickerPresentedChanged)
        ) {
            SystemPhotoPicker(
                onLoadingStarted: { total in
                    store.send(.pickedMediaLoadingStarted(total: total))
                },
                onProgress: { done in
                    store.send(.pickedMediaProgressUpdated(done: done))
                },
                onPicked: { media in
                    store.send(.photosPickedFromSystemPicker(media: media))
                }
            )
            .ignoresSafeArea()
        }
        .sheet(
            item: Binding(
                get: { store.previewAsset },
                set: { if $0 == nil { store.send(.previewDismissed) } }
            )
        ) { asset in
            MediaPreviewSheet(asset: asset, store: store)
        }
        .overlay {
            if store.isPreparingPickedMedia {
                pickedMediaLoadingOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.isPreparingPickedMedia)
        // 사진 추출 중에는 화면 자동 잠금(idle timer)을 막아 작업이 중단되지 않게 한다.
        .onChange(of: store.isPreparingPickedMedia) { _, isPreparing in
            UIApplication.shared.isIdleTimerDisabled = isPreparing
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task { await store.send(.task).finish() }
    }

    // MARK: - Picked media loading overlay

    @ViewBuilder
    private var pickedMediaLoadingOverlay: some View {
        ChalNaBlockingOverlay(
            title: "사진을 불러오는 중",
            detail: "Live Photo와 영상을 정성껏 추출하고 있어요",
            progressText: loadingProgressText,
            accessibilityLabel: "사진을 불러오는 중이에요"
        )
    }

    /// total 자릿수에 맞춰 done 을 0 패딩 (총 12개 → "05 / 12", 총 9개 → "5 / 9").
    private var loadingProgressText: String? {
        guard let progress = store.preparingPickedMediaProgress, progress.total > 0 else { return nil }
        let doneText = String(format: "%0\(String(progress.total).count)d", progress.done)
        return "\(doneText) / \(progress.total)"
    }

    // MARK: - Header

    private var header: some View {
        ChalNaNavBar(
            title: "미디어 선택",
            leading: .back {
                dismissTitleKeyboard()
                store.send(.dismissTapped)
            }
        )
        .chalNaScrollHairline(progress: store.scrollProgress)
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            introHeadline
                .foregroundColor(ChalNaColor.textPrimary)
            Text("Live Photo와 짧은 영상을 불러올 수 있어요.\nLive Photo는 내부의 영상 부분을 사용합니다.")
                .font(ChalNaTypography.label)
                .foregroundColor(ChalNaColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 첫 줄(display)·둘째 줄(title) 폰트가 달라 Text 두 개를 합치지만,
    /// 로컬라이즈 키는 합쳐진 한 문장이라 번역을 가져와 \n 기준으로 쪼갠다.
    private var introHeadline: Text {
        let full = String(localized: "찰나의 순간을\n천천히 골라보세요.")
        let lines = full.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let first = String(lines.first ?? "")
        let second = lines.count > 1 ? String(lines[1]) : ""
        return Text(verbatim: first + "\n").font(ChalNaTypography.display)
             + Text(verbatim: second).font(ChalNaTypography.title)
    }

    // MARK: - Title field

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChalNaTextField(
                label: String(localized: "이번 필름의 제목"),
                placeholder: String(localized: "예: 제주도, 우리의 봄"),
                helper: String(localized: "비워두면 나중에 자동으로 채워져요."),
                text: $store.titleInput.sending(\.titleChanged)
            )
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
            ChalNaCard(showsBorder: false) {
                HStack(spacing: 12) {
                    ChalNaIcon(.plus, size: 18).foregroundColor(ChalNaColor.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(photoLauncherTitle)
                            .font(ChalNaTypography.headline)
                            .foregroundColor(ChalNaColor.textPrimary)
                        Text(photoLauncherSubtitle)
                            .font(ChalNaTypography.caption)
                            .foregroundColor(ChalNaColor.textSecondary)
                    }
                    Spacer()
                    ChalNaIcon(.chevronRight, size: 14).foregroundColor(ChalNaColor.textSecondary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                    .strokeBorder(ChalNaColor.accent.opacity(0.5),
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
            ChalNaCard(showsBorder: false) {
                HStack(spacing: 12) {
                    ChalNaIcon(.film, size: 18).foregroundColor(ChalNaColor.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dev 미디어 소스")
                            .font(ChalNaTypography.headline)
                            .foregroundColor(ChalNaColor.textPrimary)
                        Text(store.selectedDevAssetIDs.isEmpty
                             ? LocalizedStringKey("번들 fixture로 실제 export까지 확인")
                             : LocalizedStringKey("\(store.selectedDevAssetIDs.count)개 fixture 선택됨"))
                            .font(ChalNaTypography.caption)
                            .foregroundColor(ChalNaColor.textSecondary)
                    }
                    Spacer()
                    ChalNaTag("DEV", variant: .neutral)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                    .strokeBorder(ChalNaColor.accent.opacity(0.45), lineWidth: 1.2)
            )

            if let devErrorMessage = store.devErrorMessage {
                Text(devErrorMessage)
                    .font(ChalNaTypography.caption)
                    .foregroundColor(ChalNaColor.accent)
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
                    ChalNaTag("\(selectedLiveCount) LIVE", variant: .live)
                }
                if selectedVideoCount > 0 {
                    ChalNaTag("\(selectedVideoCount) VIDEO", variant: .video, icon: .video)
                }
            }

            if let statusMessage = photoStatusMessage {
                HStack(spacing: 8) {
                    if isPreparingMedia || store.isPhotoLibraryLoading {
                        ProgressView().controlSize(.small).tint(ChalNaColor.accent)
                    } else {
                        ChalNaIcon(.download, size: 12)
                    }
                    Text(statusMessage)
                        .font(ChalNaTypography.label)
                }
                .foregroundColor(photoStatusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
                        .fill(ChalNaColor.surface)
                )
            }

            if selectedAssets.isEmpty {
                Text(photoEmptyMessage)
                    .font(ChalNaTypography.body)
                    .foregroundColor(ChalNaColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 10
                ) {
                    ForEach(Array(selectedAssets.enumerated()), id: \.element.id) { idx, asset in
                        MediaThumb(state: .selected) {
                            photoThumbnail(for: asset)
                        }
                        .overlay(alignment: .topLeading) {
                            kindTag(for: asset.kind)
                                .padding(4)
                                .allowsHitTesting(false)
                        }
                        .overlay(alignment: .topTrailing) {
                            removeBadge(for: asset)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissTitleKeyboard()
                            store.send(.previewRequested(asset))
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(thumbnailAccessibilityLabel(for: asset, index: idx, isSelected: true))
                        .accessibilityHint("탭하면 미리보기가 열려요")
                        .accessibilityAction {
                            store.send(.previewRequested(asset))
                        }
                        .accessibilityAction(named: Text("선택에서 제외")) {
                            store.send(.photoAssetTapped(asset))
                        }
                    }
                }
                .padding(.top, 12)
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
                    ChalNaTag("\(devLiveCount) LIVE", variant: .live)
                }
                if devVideoCount > 0 {
                    ChalNaTag("\(devVideoCount) VIDEO", variant: .video, icon: .video)
                }
            }

            if store.devAssets.isEmpty {
                Text("Dev 미디어를 준비하고 있어요")
                    .font(ChalNaTypography.body)
                    .foregroundColor(ChalNaColor.textSecondary)
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
                        .accessibilityLabel("\(asset.title), \(asset.kind == .live ? String(localized: "라이브 포토") : String(localized: "비디오"))")
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
                    ChalNaColor.surface
                    ChalNaIcon(.close, size: 14).foregroundColor(ChalNaColor.textSecondary)
                }
            } else {
                ChalNaColor.surface
                ProgressView().tint(ChalNaColor.accent)
            }

            if state.kind == .video {
                Circle()
                    .fill(ChalNaColor.surfaceRaised.opacity(0.92))
                    .frame(width: 22, height: 22)
                    .overlay(ChalNaIcon(.play, size: 9).foregroundColor(ChalNaColor.textPrimary).offset(x: 1))
            }

            if state.videoFailed && state.thumbnail != nil {
                Text("영상 X")
                    .font(ChalNaTypography.caption)
                    .foregroundColor(ChalNaColor.textPrimary)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(ChalNaColor.surfaceRaised.opacity(0.92)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(4)
            }
        }
    }

    @ViewBuilder
    private func kindTag(for kind: PhotoLibraryAssetKind) -> some View {
        switch kind {
        case .livePhoto: ChalNaTag("LIVE", variant: .live)
        case .video:     ChalNaTag("VIDEO", variant: .video, icon: .video)
        case .image, .unknown: EmptyView()
        }
    }

    /// 선택 제외 X 버튼. 본문 탭(미리보기)과 분리된 히트 영역 44pt.
    private func removeBadge(for asset: PhotoLibraryAsset) -> some View {
        Button {
            dismissTitleKeyboard()
            store.send(.photoAssetTapped(asset))
        } label: {
            ChalNaIcon(.close, size: 11, weight: .bold)
                .foregroundColor(ChalNaColor.onAccent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(ChalNaColor.accentFill))
                .overlay(Circle().strokeBorder(ChalNaColor.canvas.opacity(0.4), lineWidth: 1))
                .frame(width: 44, height: 44, alignment: .topTrailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("선택에서 제외")
        .accessibilityHint("\(asset.kind == .video ? String(localized: "비디오") : String(localized: "라이브 포토"))를 선택에서 빼요")
    }

    // MARK: - Bottom bar

    private var bottomActionArea: some View {
        bottomBar
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                ChalNaColor.bg
                    .ignoresSafeArea(edges: .bottom)
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(ChalNaColor.border)
                    .frame(height: 1)
            }
    }

    @ViewBuilder
    private var bottomBar: some View {
        chalNaBottomBar
    }

    private var chalNaBottomBar: some View {
        HStack(spacing: 10) {
            Button {
                dismissTitleKeyboard()
                store.send(.dismissTapped)
            } label: {
                Text("취소").frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))

            Button {
                store.send(.primaryActionTapped)
            } label: {
                confirmBottomLabel.frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
            .disabled(!canUsePrimaryAction || store.isResolving)
        }
    }

    private var confirmBottomLabel: some View {
        HStack(spacing: 6) {
            if store.isResolving || isPreparingMedia {
                ProgressView().controlSize(.small).tint(ChalNaColor.onAccent)
            } else {
                ChalNaIcon(.check, size: 14)
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
            return String(localized: "사진 권한을 허용해야 Live Photo 영상을 사용할 수 있어요.")
        }
        if status == .notDetermined {
            return String(localized: "먼저 사진 권한 범위를 선택해 주세요.")
        }
        if store.isPhotoLibraryLoading {
            return String(localized: "선택한 사진을 불러오는 중")
        }
        if hasUnavailableMedia {
            return String(localized: "선택한 항목을 불러오지 못했어요. 다시 선택해 주세요.")
        }
        if !store.selectedAssetIDs.isEmpty, readyMediaCount < store.selectedAssetIDs.count {
            return String(localized: "사진 로딩 중 · \(readyMediaCount)/\(store.selectedAssetIDs.count)")
        }
        return nil
    }

    private var photoStatusColor: Color {
        if hasUnavailableMedia || store.photoAuthorizationStatus == .denied || store.photoAuthorizationStatus == .restricted {
            return ChalNaColor.accent
        }
        return ChalNaColor.textSecondary
    }

    private var confirmButtonTitle: String {
        if selectedCount == 0 {
            return String(localized: "선택 후 다음")
        }
        if case .photoLibrary = store.source {
            if hasUnavailableMedia { return String(localized: "원본 확인 필요") }
            if !canProceed { return String(localized: "사진 로딩 중") }
        }
        return String(localized: "Timeline으로 (\(selectedCount))")
    }

    private var selectedCount: Int {
        switch store.source {
        case .photoLibrary: return store.selectedAssetIDs.count
        case .devFixtures:  return store.selectedDevAssetIDs.count
        }
    }

    private var photoLauncherTitle: String {
        let status = store.photoAuthorizationStatus
        if status == .notDetermined { return String(localized: "사진 권한 선택") }
        if status == .denied || status == .restricted { return String(localized: "사진 권한 열기") }
        return store.selectedAssetIDs.isEmpty ? String(localized: "사진 추가하기") : String(localized: "다시 고르기")
    }

    private var photoLauncherSubtitle: String {
        let status = store.photoAuthorizationStatus
        if status == .notDetermined { return String(localized: "먼저 권한 범위를 고른 뒤 선택해요") }
        if status == .denied || status == .restricted { return String(localized: "설정에서 사진 접근을 허용해 주세요") }
        if store.isPhotoLibraryLoading { return String(localized: "선택한 사진을 불러오는 중") }
        if store.selectedAssetIDs.isEmpty { return String(localized: "Live Photo와 짧은 영상만 가져올 수 있어요") }
        return String(localized: "\(store.selectedAssetIDs.count)개 선택됨 · 탭해서 추가해요")
    }

    private var photoEmptyMessage: String {
        let status = store.photoAuthorizationStatus
        if status == .notDetermined { return String(localized: "먼저 사진 권한 범위를 선택해 주세요") }
        if status == .denied || status == .restricted { return String(localized: "사진 권한을 허용해야 Live Photo 영상을 만들 수 있어요") }
        if store.isPhotoLibraryLoading { return String(localized: "선택한 사진을 불러오고 있어요") }
        return String(localized: "아직 선택한 사진이 없어요. 위 카드를 눌러 골라보세요.")
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
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    private func openPhotoSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }
}

// MARK: - SystemPhotoPicker

/// PHPickerViewController 를 SwiftUI sheet 로 띄우기 위한 래퍼.
/// `.limited` 권한에서도 picker 가 임시로 부여하는 NSItemProvider 접근권으로
/// 권한 밖 사진의 paired video / movie 파일을 임시 디렉토리에 미리 추출해 둔다.
private struct SystemPhotoPicker: UIViewControllerRepresentable {
    let onLoadingStarted: (Int) -> Void
    let onProgress: (Int) -> Void
    let onPicked: ([PickedMedia]) -> Void

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

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onLoadingStarted: onLoadingStarted,
            onProgress: onProgress,
            onPicked: onPicked
        )
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onLoadingStarted: (Int) -> Void
        let onProgress: (Int) -> Void
        let onPicked: ([PickedMedia]) -> Void

        init(
            onLoadingStarted: @escaping (Int) -> Void,
            onProgress: @escaping (Int) -> Void,
            onPicked: @escaping ([PickedMedia]) -> Void
        ) {
            self.onLoadingStarted = onLoadingStarted
            self.onProgress = onProgress
            self.onPicked = onPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else {
                onPicked([])
                return
            }
            // picker가 닫히는 직후부터 PickedMediaLoader가 끝날 때까지 MediaPickerView 위에 로딩 오버레이 표출.
            // total = picker 선택 개수. PickedMediaLoader 추출 도중 비-사진 항목은 nil 로 떨어질 수 있지만
            // "총 N개 중 X 처리 완료" 카운트는 picker 선택 수 기준으로 안내한다.
            let total = results.count
            onLoadingStarted(total)
            let progress = onProgress
            Task { [onPicked] in
                let media = await PickedMediaLoader.load(from: results) { done in
                    Task { @MainActor in progress(done) }
                }
                await MainActor.run { onPicked(media) }
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
            MediaThumb(
                state: isSelected ? .selected : .normal,
                size: CGSize(width: 112, height: 142)
            ) {
                ZStack {
                    asset.preset.view()
                    LinearGradient(
                        colors: [.clear, ChalNaColor.canvas.opacity(0.5)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    kindTag
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(4)
                    if asset.kind == .video {
                        Circle()
                            .fill(ChalNaColor.surfaceRaised.opacity(0.92))
                            .frame(width: 24, height: 24)
                            .overlay(
                                ChalNaIcon(.play, size: 10)
                                    .foregroundColor(ChalNaColor.textPrimary)
                                    .offset(x: 1)
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.title)
                    .font(ChalNaTypography.headline)
                    .foregroundColor(ChalNaColor.textPrimary)
                    .lineLimit(1)
                Text(asset.locationNote ?? String(format: "%.1fs", asset.duration))
                    .font(ChalNaTypography.caption)
                    .foregroundColor(ChalNaColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                .fill(ChalNaColor.surface.opacity(isSelected ? 1 : 0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                .strokeBorder(isSelected ? ChalNaColor.accent : ChalNaColor.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var kindTag: some View {
        switch asset.kind {
        case .live:  ChalNaTag("LIVE", variant: .live)
        case .video: ChalNaTag("VIDEO", variant: .video, icon: .video)
        }
    }
}

#Preview("MediaPicker — empty") {
    MediaPickerView(source: .photoLibrary)
}

#Preview("MediaPicker — selected") {
    var state = MediaPickerFeature.State(source: .photoLibrary, photoAuthorizationStatus: .authorized)
    let assets = [
        PhotoLibraryAsset(id: "p1", kind: .livePhoto, capturedAt: nil, pixelSize: .zero),
        PhotoLibraryAsset(id: "p2", kind: .video, capturedAt: nil, pixelSize: .zero)
    ]
    state.photoAssets = assets
    state.selectedAssetIDs = assets.map(\.id)
    state.media["p1"] = MediaLoadState(kind: .livePhoto)
    state.media["p2"] = MediaLoadState(kind: .video)
    return MediaPickerView(store: Store(initialState: state) { MediaPickerFeature() })
}

#Preview("MediaPicker — Dev") {
    MediaPickerView(source: .devFixtures(BundledDevMediaSource()))
}
