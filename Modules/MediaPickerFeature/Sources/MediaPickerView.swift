import SwiftUI
import ComposableArchitecture
import DesignSystem
import PhotosService
import PhotosUI

public struct MediaPickerView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var store: StoreOf<MediaPickerFeature>

    public init(store: StoreOf<MediaPickerFeature>) {
        self.store = store
    }

    public init(source: MediaPickerSource = .photoLibrary) {
        self.store = Store(initialState: MediaPickerFeature.State(source: source)) { MediaPickerFeature() }
    }

    public var body: some View {
        GeometryReader { proxy in
            let split = ChalNaLayout.isSplit(proxy.size)
            let compactList = !split && (proxy.size.width >= 600 ||
                (proxy.size.width >= 430 && proxy.size.width >= proxy.size.height * 0.62))
            VStack(alignment: .leading, spacing: 8) {
                Text("장면 선택").font(ChalNaTypography.display)
                    .foregroundStyle(ChalNaColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if split {
                    HStack(alignment: .top, spacing: 32) {
                        ScrollView {
                            if isEmptyLibrary { emptySelection }
                            else { selectionView(compact: false, showsAdd: false) }
                        }
                        .frame(maxWidth: .infinity)
                        VStack(alignment: .leading, spacing: 16) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 18) {
                                    if !isEmptyLibrary {
                                        titleField
                                        if photoLibrary {
                                            Divider()
                                            Text("Live Photo \(store.state.liveCount)개 · 동영상 \(store.state.videoCount)개")
                                                .font(ChalNaTypography.body)
                                            orderNote
                                            addButton
                                        }
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                            footer
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 12)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if isEmptyLibrary {
                                emptySelection
                            } else {
                                titleField
                                selectionView(compact: compactList, showsAdd: photoLibrary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                    }
                    if !isEmptyLibrary && store.state.canProceed { orderNote }
                    footer
                }
            }
            .padding(.horizontal, split ? 32 : 24)
            .padding(.bottom, 8)
            .scrollDismissesKeyboard(.interactively)
        }
        .chalNaScreen()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(store.isPreparingPickedMedia)
        .disabled(store.isPreparingPickedMedia)
        .accessibilityHidden(store.isPreparingPickedMedia)
        .alert("Live Photo 권한이 필요해요",
               isPresented: $store.isPhotoPermissionAlertPresented.sending(\.permissionAlertPresentedChanged)) {
            Button("앱 설정 열기") {
                store.send(.permissionAlertConfirmTapped)
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("취소", role: .cancel) { store.send(.permissionAlertDismissed) }
        } message: {
            Text("Live Photo를 영상으로 사용하려면 사진 보관함 접근 권한이 필요해요.")
        }
        .fullScreenCover(isPresented: $store.isSystemPhotoPickerPresented.sending(\.systemPhotoPickerPresentedChanged)) {
            SystemPhotoPicker { results in store.send(.systemPickerFinished(results)) }
                .ignoresSafeArea()
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .sheet(item: Binding(get: { store.previewAsset }, set: { if $0 == nil { store.send(.previewDismissed) } })) { asset in
            MediaPreviewSheet(asset: asset, store: store)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .overlay {
            if let progress = store.preparingPickedMediaProgress {
                preparation(progress)
            }
        }
        .onChange(of: store.isPreparingPickedMedia) { _, preparing in UIApplication.shared.isIdleTimerDisabled = preparing }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && photoLibrary { store.send(.task) }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task { await store.send(.task).finish() }
    }

    private func preparation(_ progress: PreparingPickedMediaProgress) -> some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("장면 선택").font(ChalNaTypography.display)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 6) {
                        ForEach(0..<min(progress.total, 4), id: \.self) { index in
                            Rectangle().fill(ChalNaColor.surface)
                                .aspectRatio(0.85, contentMode: .fit)
                                .overlay {
                                    if let data = progress.thumbnail(at: index), let image = UIImage(data: data) {
                                        Image(uiImage: image).resizable().scaledToFill()
                                    } else {
                                        ChalNaIcon(.film, size: 20).foregroundStyle(ChalNaColor.textSecondary)
                                    }
                                }
                                .clipped()
                                .frame(maxWidth: 114)
                        }
                    }
                    .accessibilityHidden(true)
                    Text("장면을 준비하는 중").font(ChalNaTypography.screenTitle)
                    Text("Live Photo와 동영상 원본을 불러오고 있어요.")
                        .font(ChalNaTypography.body).foregroundStyle(ChalNaColor.textSecondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text("전체 \(progress.total)개 중 \(progress.done)개 처리")
                            .font(ChalNaTypography.body)
                            .accessibilityIdentifier("picker.preparationCount")
                        Spacer(minLength: 8)
                        Text(progress.fractionCompleted, format: .percent.precision(.fractionLength(0)).rounded(rule: .down))
                            .font(ChalNaTypography.title).foregroundStyle(ChalNaColor.accent)
                            .monospacedDigit()
                            .accessibilityHidden(true)
                    }
                    ChalNaProgressBar(progress: progress.fractionCompleted)
                        .accessibilityIdentifier("picker.preparationProgress")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            Button("취소", role: .cancel) { store.send(.cancelPreparingPickedMedia) }
                .buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
                .accessibilityIdentifier("picker.cancelPreparation")
        }
        .foregroundStyle(ChalNaColor.textPrimary)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: 540, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChalNaColor.bg.ignoresSafeArea())
        .accessibilityAddTraits(.isModal)
    }

    private var photoLibrary: Bool {
        if case .photoLibrary = store.source { return true }
        return false
    }

    private var isEmptyLibrary: Bool { photoLibrary && store.selectedAssetIDs.isEmpty }

    private var denied: Bool {
        store.photoAuthorizationStatus == .denied || store.photoAuthorizationStatus == .restricted
    }

    private var emptySelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ChalNaIcon(.film, size: 28)
                .foregroundStyle(ChalNaColor.accent)
                .frame(width: 60, height: 60)
                .background(ChalNaColor.surface, in: RoundedRectangle(cornerRadius: ChalNaRadius.sm))
            Text(denied ? "사진 접근이 꺼져 있어요" : "어떤 장면을 담을까요?")
                .font(ChalNaTypography.title).foregroundStyle(ChalNaColor.textPrimary)
            Text(denied
                 ? "설정에서 찰나의 사진 접근을 허용하면 Live Photo와 동영상을 선택할 수 있어요."
                 : "사진 보관함에서 Live Photo와 동영상을 골라 한 편의 필름으로 만들어요.")
                .font(ChalNaTypography.body).foregroundStyle(ChalNaColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 32)
    }

    private var titleField: some View {
        ChalNaTextField(label: String(localized: "필름 제목 (선택)"),
                        placeholder: String(localized: "필름 제목"),
                        text: $store.titleInput.sending(\.titleChanged))
            .accessibilityIdentifier("picker.title")
    }

    private var orderNote: some View {
        Text("타임라인에서 촬영한 순서대로 이어져요.")
            .font(ChalNaTypography.label).foregroundStyle(ChalNaColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addButton: some View {
        Button { store.send(.photoLauncherTapped) } label: {
            Text(store.state.hasUnavailableMedia ? LocalizedStringKey("다시 선택하기") : "추가").font(ChalNaTypography.headline).foregroundStyle(ChalNaColor.accent)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.state.hasUnavailableMedia ? LocalizedStringKey("다시 선택하기") : "사진 보관함에서 추가")
        .accessibilityIdentifier("picker.openLibrary")
    }

    @ViewBuilder
    private func selectionView(compact: Bool, showsAdd: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("선택한 미디어 \(store.state.selectedCount)개")
                    .font(ChalNaTypography.headline).foregroundStyle(ChalNaColor.textPrimary)
                Spacer()
                if showsAdd { addButton }
            }
            if let error = store.devErrorMessage {
                Text(verbatim: error).foregroundStyle(ChalNaColor.danger)
            }
            if store.state.hasUnavailableMedia {
                Text("선택한 항목을 불러오지 못했어요. 다시 선택해 주세요.")
                    .font(ChalNaTypography.body).foregroundStyle(ChalNaColor.danger)
            }
            if photoLibrary {
                let assets = store.state.selectedAssets
                if compact {
                    LazyVStack(spacing: 8) {
                        ForEach(assets) { asset in
                            HStack(spacing: 12) {
                                Button { store.send(.previewRequested(asset)) } label: {
                                    HStack(spacing: 12) {
                                        thumbnail(asset).frame(width: 58, height: 58)
                                        VStack(alignment: .leading, spacing: 4) {
                                            capturedTime(asset)
                                            metadata(asset, includeDuration: true)
                                        }
                                        Spacer()
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                removeButton(asset)
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 14) {
                        ForEach(assets) { asset in
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    Button { store.send(.previewRequested(asset)) } label: {
                                        thumbnail(asset).aspectRatio(0.95, contentMode: .fit)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text("\(assetDescription(asset)) 미리보기"))
                                    removeButton(asset)
                                }
                                HStack {
                                    capturedTime(asset)
                                    Spacer(minLength: 2)
                                    metadata(asset, includeDuration: false)
                                }
                            }
                        }
                    }
                }
            } else {
                devGrid
            }
        }
    }

    private func thumbnail(_ asset: PhotoLibraryAsset) -> some View {
        let media = store.media[asset.id]
        return Rectangle().fill(ChalNaColor.surface)
            .overlay {
                if let data = media?.thumbnail ?? store.assetThumbnails[asset.id], let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if media?.thumbnailFailed != true {
                    ProgressView().tint(ChalNaColor.accent)
                }
                if media?.didFailTimelinePreparation == true {
                    ChalNaIcon(.close, size: 16)
                        .foregroundStyle(ChalNaColor.onMedia)
                        .frame(width: 28, height: 28)
                        .background(ChalNaColor.onMediaDark.opacity(0.72), in: Circle())
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.xxs))
    }

    private func capturedTime(_ asset: PhotoLibraryAsset) -> some View {
        Group {
            if let date = asset.capturedAt { Text(date, style: .time) }
            else { Text("시간 정보 없음") }
        }
        .font(ChalNaTypography.label).foregroundStyle(ChalNaColor.textPrimary)
    }

    private func kindName(_ asset: PhotoLibraryAsset) -> String {
        switch asset.kind {
        case .livePhoto: return "Live Photo"
        case .video: return String(localized: "동영상")
        case .image: return String(localized: "사진")
        case .unknown: return String(localized: "미디어")
        }
    }

    private func assetDescription(_ asset: PhotoLibraryAsset) -> String {
        let time = asset.capturedAt?.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        return [kindName(asset), time].compactMap { $0 }.joined(separator: ", ")
    }

    private func metadata(_ asset: PhotoLibraryAsset, includeDuration: Bool) -> some View {
        let duration = includeDuration ? store.media[asset.id]?.duration : nil
        let suffix = duration.map { " · " + String(format: String(localized: "%.1f초"), $0) } ?? ""
        return Text(verbatim: kindName(asset) + suffix)
            .font(ChalNaTypography.caption).foregroundStyle(ChalNaColor.textSecondary)
    }

    private func removeButton(_ asset: PhotoLibraryAsset) -> some View {
        Button { store.send(.photoAssetTapped(asset)) } label: {
            ChalNaIcon(.close, size: 10, weight: .bold)
                .foregroundStyle(ChalNaColor.onMedia)
                .frame(width: 24, height: 24)
                .background(ChalNaColor.onMediaDark.opacity(0.8), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("선택에서 제외")
        .accessibilityValue(Text(verbatim: assetDescription(asset)))
    }

    private var devGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            ForEach(store.devAssets) { asset in
                let selected = store.selectedDevAssetIDs.contains(asset.id)
                Button { store.send(.devAssetTapped(asset.id)) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Rectangle().fill(ChalNaColor.surface)
                            .overlay { asset.preset.view() }
                            .aspectRatio(1.8, contentMode: .fit)
                            .clipped()
                            .overlay(alignment: .topTrailing) {
                                if selected {
                                    ChalNaIcon(.check, size: 14).foregroundStyle(ChalNaColor.onAccent)
                                        .padding(5).background(ChalNaColor.accentFill, in: Circle()).padding(6)
                                }
                            }
                        Text(verbatim: asset.title).font(ChalNaTypography.headline)
                        Text(asset.capturedAt, style: .time).font(ChalNaTypography.caption)
                            .foregroundStyle(ChalNaColor.textSecondary)
                    }.foregroundStyle(ChalNaColor.textPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: asset.title))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var footer: some View {
        Button {
            if isEmptyLibrary { store.send(.photoLauncherTapped) }
            else { store.send(.primaryActionTapped) }
        } label: {
            HStack {
                ChalNaIcon(isEmptyLibrary ? .plus : .chevronRight, size: 15)
                Spacer()
                Text(actionTitle)
                Spacer()
                Color.clear.frame(width: 15, height: 1)
            }
        }
        .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
        .disabled(store.isResolving || (!isEmptyLibrary && !store.state.canProceed))
        .accessibilityIdentifier(isEmptyLibrary ? "picker.openLibrary" : "picker.confirm")
    }

    private var actionTitle: String {
        if isEmptyLibrary { return denied ? String(localized: "앱 설정 열기") : String(localized: "사진 보관함 열기") }
        if store.state.hasUnavailableMedia { return String(localized: "원본 확인 필요") }
        if store.state.selectedCount == 0 { return String(localized: "선택 후 다음") }
        if !store.state.canProceed || store.isResolving { return String(localized: "장면을 준비하는 중") }
        return String(localized: "\(store.state.selectedCount)개 장면 편집하기")
    }
}

private struct SystemPhotoPicker: UIViewControllerRepresentable {
    let onPicked: ([any PickedMediaLoading]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .any(of: [.livePhotos, .videos])
        config.selectionLimit = 0
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: ([any PickedMediaLoading]) -> Void
        init(onPicked: @escaping ([any PickedMediaLoading]) -> Void) { self.onPicked = onPicked }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            onPicked(results.map { PickedMediaLoader(assetID: $0.assetIdentifier, provider: $0.itemProvider) })
        }
    }
}
