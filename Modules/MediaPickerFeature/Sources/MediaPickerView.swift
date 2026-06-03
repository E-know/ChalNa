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
            header.chalNaHeaderBar(scrollProgress: store.scrollProgress)
                .simultaneousGesture(TapGesture().onEnded { dismissTitleKeyboard() })
                .zIndex(1)

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
        .onChange(of: store.confirmation?.id) { _, newID in
            guard newID != nil, let confirmation = store.confirmation else { return }
            session.replace(clips: confirmation.clips, title: confirmation.title)
            router.push(.timeline)
        }
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

    private var pickedMediaLoadingOverlay: some View {
        ZStack {
            ChalNaColor.ink.opacity(0.32)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { } // 하단 화면 탭 차단

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(ChalNaColor.coral)

                VStack(spacing: 6) {
                    Text("사진을 불러오는 중")
                        .font(ChalNaTypography.krSemibold(15))
                        .foregroundColor(ChalNaColor.ink)

                    if let progress = store.preparingPickedMediaProgress, progress.total > 0 {
                        // total 자릿수에 맞춰 done 을 0 패딩 (예: 총 12개 → "05 / 12", 총 9개 → "5 / 9")
                        let doneText = String(format: "%0\(String(progress.total).count)d", progress.done)
                        Text("\(doneText) / \(progress.total)")
                            .font(ChalNaTypography.monoFallback(22, weight: .bold))
                            .foregroundColor(ChalNaColor.coral)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(progress.done)))
                            .animation(.easeOut(duration: 0.2), value: progress.done)
                            .accessibilityLabel("\(progress.total)개 중 \(progress.done)개 완료")
                    }

                    Text("Live Photo와 영상을 정성껏 추출하고 있어요")
                        .font(ChalNaTypography.krBody(12))
                        .foregroundColor(ChalNaColor.taupe)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(minWidth: 220)
            .background(
                RoundedRectangle(cornerRadius: ChalNaRadius.sheet, style: .continuous)
                    .fill(ChalNaColor.white)
            )
            .chalNaShadow(ChalNaShadow.lg)
            .padding(.horizontal, 48)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("사진을 불러오는 중이에요")
    }

    // MARK: - Header

    private var header: some View {
        ChalNaNavigationHeader(
            titleKey: "미디어 선택",
            subtitleKey: "LIVE · VIDEO",
            subtitleColor: ChalNaColor.coral
        ) {
            ChalNaHeaderBackButton {
                dismissTitleKeyboard()
                store.send(.dismissTapped)
                router.pop()
            }
        } trailing: {
            EmptyView()
        }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PICK · YOUR CHALNA").tagLabel()
            introHeadline
                .foregroundColor(ChalNaColor.ink)
                .lineSpacing(2)
            Text("Live Photo와 짧은 영상을 불러올 수 있어요.\nLive Photo는 내부의 영상 부분을 사용합니다.")
                .font(ChalNaTypography.krBody(13))
                .foregroundColor(ChalNaColor.taupe)
                .padding(.top, 4)
        }
    }

    /// 첫 줄(큰 display)·둘째 줄(작은 body) 폰트가 달라 Text 두 개를 합치지만,
    /// 로컬라이즈 키는 합쳐진 한 문장이라 번역을 가져와 \n 기준으로 쪼갠다(번역도 \n 위치를 따른다).
    private var introHeadline: Text {
        let full = String(localized: "찰나의 순간을\n천천히 골라보세요.")
        let lines = full.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let first = String(lines.first ?? "")
        let second = lines.count > 1 ? String(lines[1]) : ""
        return Text(first + "\n").font(ChalNaTypography.displayKR(26))
             + Text(second).font(ChalNaTypography.krBody(22, weight: .medium))
    }

    // MARK: - Title field

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TITLE · 이번 찰나 모음집의 제목").tagLabel()

            TextField(
                "",
                text: $store.titleInput.sending(\.titleChanged),
                prompt: Text("예: 제주도, 우리의 봄")
                    .font(ChalNaTypography.krBody(15))
                    .foregroundColor(ChalNaColor.taupe.opacity(0.6))
            )
            .textFieldStyle(.plain)
            .font(ChalNaTypography.krBody(16, weight: .medium))
            .foregroundColor(ChalNaColor.ink)
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
                RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                    .strokeBorder(
                        isTitleFocused
                            ? ChalNaColor.coral.opacity(0.55)
                            : ChalNaColor.taupe.opacity(0.18),
                        lineWidth: 1
                    )
            )

            Text("비워두면 나중에 자동으로 채워져요.")
                .font(ChalNaTypography.krBody(12))
                .foregroundColor(ChalNaColor.taupe)
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
                ChalNaIcon(.plus, size: 18).foregroundColor(ChalNaColor.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text(photoLauncherTitle)
                        .font(ChalNaTypography.krSemibold(15))
                        .foregroundColor(ChalNaColor.ink)
                    Text(photoLauncherSubtitle)
                        .font(ChalNaTypography.krBody(12))
                        .foregroundColor(ChalNaColor.taupe)
                }
                Spacer()
                ChalNaIcon(.chevronRight, size: 14).foregroundColor(ChalNaColor.taupe)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                    .strokeBorder(ChalNaColor.coral.opacity(0.5),
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
                ChalNaIcon(.film, size: 18).foregroundColor(ChalNaColor.coral)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dev 미디어 소스")
                        .font(ChalNaTypography.krSemibold(15))
                        .foregroundColor(ChalNaColor.ink)
                    Text(store.selectedDevAssetIDs.isEmpty
                         ? LocalizedStringKey("번들 fixture로 실제 export까지 확인")
                         : LocalizedStringKey("\(store.selectedDevAssetIDs.count)개 fixture 선택됨"))
                        .font(ChalNaTypography.krBody(12))
                        .foregroundColor(ChalNaColor.taupe)
                }
                Spacer()
                ChalNaChip("DEV", variant: .dashed)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                    .strokeBorder(ChalNaColor.coral.opacity(0.45), lineWidth: 1.2)
            )

            if let devErrorMessage = store.devErrorMessage {
                Text(devErrorMessage)
                    .font(ChalNaTypography.krBody(12))
                    .foregroundColor(ChalNaColor.coral)
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
                    ChalNaChip("\(selectedLiveCount) LIVE", variant: .live)
                }
                if selectedVideoCount > 0 {
                    ChalNaChip("\(selectedVideoCount) VIDEO", variant: .video, icon: .film)
                }
            }

            if let statusMessage = photoStatusMessage {
                HStack(spacing: 8) {
                    if isPreparingMedia || store.isPhotoLibraryLoading {
                        ProgressView().controlSize(.small).tint(ChalNaColor.coral)
                    } else {
                        ChalNaIcon(.download, size: 12)
                    }
                    Text(statusMessage)
                        .font(ChalNaTypography.krBody(12, weight: .medium))
                }
                .foregroundColor(photoStatusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: ChalNaRadius.button, style: .continuous)
                        .fill(ChalNaColor.ivory.opacity(0.75))
                )
            }

            if selectedAssets.isEmpty {
                Text(photoEmptyMessage)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                    .foregroundColor(ChalNaColor.taupe)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                    spacing: 12
                ) {
                    ForEach(Array(selectedAssets.enumerated()), id: \.element.id) { idx, asset in
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
                            removeBadge(for: asset)
                        }
                        .frame(maxWidth: .infinity)
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
                    ChalNaChip("\(devLiveCount) LIVE", variant: .live)
                }
                if devVideoCount > 0 {
                    ChalNaChip("\(devVideoCount) VIDEO", variant: .video, icon: .film)
                }
            }

            if store.devAssets.isEmpty {
                Text("Dev 미디어를 준비하고 있어요")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                    .foregroundColor(ChalNaColor.taupe)
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
                    ChalNaColor.ivory
                    ChalNaIcon(.close, size: 14).foregroundColor(ChalNaColor.taupe)
                }
            } else {
                ChalNaColor.ivory
                ProgressView().tint(ChalNaColor.coral)
            }

            if state.kind == .video {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 22, height: 22)
                    .overlay(ChalNaIcon(.play, size: 9).foregroundColor(ChalNaColor.ink).offset(x: 1))
            }

            if state.videoFailed && state.thumbnail != nil {
                Text("영상 X")
                    .font(ChalNaTypography.monoFallback(8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(ChalNaColor.taupe.opacity(0.9)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(4)
            }
        }
    }

    @ViewBuilder
    private func kindChip(for kind: PhotoLibraryAssetKind) -> some View {
        switch kind {
        case .livePhoto: ChalNaChip("LIVE", variant: .live)
        case .video:     ChalNaChip("VIDEO", variant: .video, icon: .film)
        case .image, .unknown: EmptyView()
        }
    }

    /// 선택된 미디어를 선택에서 제외하는 코너 X 버튼. 본문 탭(미리보기)과 분리된 히트 영역.
    private func removeBadge(for asset: PhotoLibraryAsset) -> some View {
        Button {
            dismissTitleKeyboard()
            store.send(.photoAssetTapped(asset))
        } label: {
            ChalNaIcon(.close, size: 10)
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(ChalNaColor.coral))
                .frame(width: 40, height: 40, alignment: .topTrailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("선택에서 제외")
        .accessibilityHint("\(asset.kind == .video ? String(localized: "비디오") : String(localized: "라이브 포토"))를 선택에서 빼요")
    }

    // MARK: - Bottom bar

    private var bottomActionArea: some View {
        bottomBar
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                ChalNaColor.white
                    .ignoresSafeArea(edges: .bottom)
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(ChalNaColor.Gray.g200)
                    .frame(height: 1)
            }
    }

    @ViewBuilder
    private var bottomBar: some View {
        chalNaBottomBar
    }

    private var chalNaBottomBar: some View {
        HStack(spacing: 8) {
            Button {
                dismissTitleKeyboard()
                store.send(.dismissTapped)
                router.pop()
            } label: {
                Text("취소").frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNaOutline)
            .frame(maxWidth: .infinity)

            Button {
                store.send(.primaryActionTapped)
            } label: {
                confirmBottomLabel.frame(maxWidth: .infinity)
            }
            .buttonStyle(.chalNaCoral)
            .frame(maxWidth: .infinity)
            .disabled(!canUsePrimaryAction || store.isResolving)
        }
    }

    private var confirmBottomLabel: some View {
        HStack(spacing: 6) {
            if store.isResolving || isPreparingMedia {
                ProgressView().controlSize(.small).tint(ChalNaColor.ink)
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
            return ChalNaColor.coral
        }
        return ChalNaColor.taupe
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
        isTitleFocused = false
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
            ClipThumbCard(
                state: isSelected ? .selected : .normal,
                size: CGSize(width: 112, height: 142)
            ) {
                ZStack {
                    asset.preset.view()
                    LinearGradient(
                        colors: [.clear, ChalNaColor.ink.opacity(0.5)],
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
                                ChalNaIcon(.play, size: 10)
                                    .foregroundColor(ChalNaColor.ink)
                                    .offset(x: 1)
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.title)
                    .font(ChalNaTypography.krSemibold(13))
                    .foregroundColor(ChalNaColor.ink)
                    .lineLimit(1)
                Text(asset.locationNote ?? String(format: "%.1fs", asset.duration))
                    .font(ChalNaTypography.krBody(11))
                    .foregroundColor(ChalNaColor.taupe)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 1 : 0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .strokeBorder(isSelected ? ChalNaColor.coral : ChalNaColor.taupe.opacity(0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var kindChip: some View {
        switch asset.kind {
        case .live:  ChalNaChip("LIVE", variant: .live).scaleEffect(0.72, anchor: .topLeading)
        case .video: ChalNaChip("VIDEO", variant: .video, icon: .film).scaleEffect(0.72, anchor: .topLeading)
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
