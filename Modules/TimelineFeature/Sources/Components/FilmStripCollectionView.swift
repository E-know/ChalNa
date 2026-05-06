import SwiftUI
import AppCore
import Models
import DesignSystem
import UIKit

// MARK: - SwiftUI bridge

/// `UICollectionView` 기반 FilmStrip 의 SwiftUI 진입점.
///
/// SwiftUI의 long-press → drag&drop 제스처 합성이 production-grade가 아니어서
/// 14년간 검증된 UIKit `UICollectionView` drag-and-drop API로 전환.
///
/// - Drag preview는 UIWindow 레벨에서 렌더링 → 화면 어디서든 손가락 추적 (strip 박스 무관)
/// - Long-press 타이밍은 iOS가 직접 관리 → 0.5s 미만 터치는 절대 활성화 안 됨
/// - Auto-scroll near edges built-in
struct FilmStripCollectionView: UIViewControllerRepresentable {
    let model: TimelineModel
    let session: EditSession
    let onTapClip: (Int) -> Void

    func makeUIViewController(context: Context) -> FilmStripVC {
        FilmStripVC()
    }

    func updateUIViewController(_ vc: FilmStripVC, context: Context) {
        vc.update(model: model, session: session, onTapClip: onTapClip)
    }
}

// MARK: - UIKit view controller

final class FilmStripVC: UIViewController,
                          UICollectionViewDragDelegate,
                          UICollectionViewDropDelegate,
                          UICollectionViewDelegate {

    /// 단일 section 내에서 day sprocket과 clip cell을 섞기 위한 item identifier.
    /// 같은 dayKey가 reorder 후 여러 번 등장할 수 있으므로 occurrenceIndex로 unique 하게.
    enum FilmStripItem: Hashable {
        case daySprocket(occurrenceIndex: Int, dayKey: String)
        case clip(Clip.ID)
    }

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, FilmStripItem>!

    // SwiftUI에서 매 update 마다 다시 받아 캐시.
    private var clips: [Clip] = []
    private weak var model: TimelineModel?
    private weak var session: EditSession?
    private var currentClipID: Clip.ID?
    private var isPlaying: Bool = false
    private var rotationByClipID: [Clip.ID: ClipRotation] = [:]
    private var onTapClip: ((Int) -> Void)?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        // 셀 그림자가 잘리지 않도록 — 셀 자체는 collection view 내부에 있어 horizontal scroll 영역만 클리핑됨.
        view.clipsToBounds = false
        setupCollectionView()
    }

    private func setupCollectionView() {
        let layout = makeLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor(named: "MomentsInk") ?? .black
        collectionView.layer.cornerRadius = 16
        collectionView.layer.cornerCurve = .continuous
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let clipCellReg = UICollectionView.CellRegistration<UICollectionViewCell, Clip.ID> { [weak self] cell, _, clipID in
            self?.configureClipCell(cell, clipID: clipID)
        }
        let dayCellReg = UICollectionView.CellRegistration<UICollectionViewCell, FilmStripItem> { [weak self] cell, _, item in
            self?.configureDayCell(cell, item: item)
        }

        dataSource = UICollectionViewDiffableDataSource<Int, FilmStripItem>(collectionView: collectionView) { cv, indexPath, item in
            switch item {
            case .clip(let id):
                return cv.dequeueConfiguredReusableCell(using: clipCellReg, for: indexPath, item: id)
            case .daySprocket:
                return cv.dequeueConfiguredReusableCell(using: dayCellReg, for: indexPath, item: item)
            }
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .estimated(50),
            heightDimension: .absolute(80)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .estimated(50),
            heightDimension: .absolute(80)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .horizontal
        return UICollectionViewCompositionalLayout(section: section, configuration: config)
    }

    // MARK: - Cell configuration

    private func configureClipCell(_ cell: UICollectionViewCell, clipID: Clip.ID) {
        guard let clip = clips.first(where: { $0.id == clipID }) else { return }
        let userRotation = session?.rotation(for: clipID) ?? .r0
        let isCurrent = clipID == currentClipID
        let visualState: ClipThumbState = isCurrent
            ? (isPlaying ? .playing : .selected)
            : (isPlaying ? .dimmed : .normal)
        let flatIndex = clips.firstIndex(where: { $0.id == clipID }) ?? 0
        let cardRotation = Self.rotationDegrees(forIndex: flatIndex)

        cell.contentConfiguration = UIHostingConfiguration {
            VStack(spacing: 4) {
                ClipThumbCard(state: visualState, rotationDegrees: cardRotation) {
                    ZStack {
                        RotatableContent(rotation: userRotation) {
                            clip.thumbnailView()
                        }
                        if clip.kind == .live {
                            LiveBadge(size: 10)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(2)
                        }
                    }
                }
                Text(clip.durationSecondsLabel)
                    .font(MomentsTypography.monoFallback(9, weight: .medium))
                    .foregroundColor(visualState == .selected || visualState == .playing
                        ? MomentsColor.coral
                        : MomentsColor.cream.opacity(0.7))
            }
        }
        .margins(.all, 0)
        // 셀 자체 그림자 클리핑 방지 (rotation/shadow가 셀 bounds 밖으로 살짝 뻗음).
        cell.contentView.clipsToBounds = false
        cell.clipsToBounds = false
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = accessibilityLabel(for: clip, index: flatIndex, isCurrent: isCurrent)
        cell.accessibilityHint = "선택하려면 두 번 탭하고, 순서를 바꾸려면 사용자 동작을 사용하세요."
        var traits: UIAccessibilityTraits = [.button]
        if isCurrent { traits.insert(.selected) }
        cell.accessibilityTraits = traits
        cell.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "앞으로 이동") { [weak self] _ in
                self?.moveClipForAccessibility(clipID, by: -1) ?? false
            },
            UIAccessibilityCustomAction(name: "뒤로 이동") { [weak self] _ in
                self?.moveClipForAccessibility(clipID, by: 1) ?? false
            },
        ]
    }

    private func configureDayCell(_ cell: UICollectionViewCell, item: FilmStripItem) {
        guard case .daySprocket(_, let dayKey) = item else { return }
        let highlighted = highlightedDayKey() == dayKey
        cell.contentConfiguration = UIHostingConfiguration {
            DaySprocket(label: dayKey, highlighted: highlighted)
        }
        .margins(.all, 0)
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = "\(dayKey) 촬영일"
        cell.accessibilityTraits = [.staticText]
        cell.accessibilityCustomActions = nil
    }

    private func highlightedDayKey() -> String? {
        guard isPlaying, let id = currentClipID,
              let clip = clips.first(where: { $0.id == id }) else { return nil }
        let df = DateFormatter()
        df.dateFormat = "MM.dd"
        return df.string(from: clip.capturedAt)
    }

    // MARK: - Update from SwiftUI

    func update(model: TimelineModel, session: EditSession, onTapClip: @escaping (Int) -> Void) {
        let previousItems = dataSource.snapshot().itemIdentifiers
        let previousCurrentClipID = currentClipID
        let previousIsPlaying = isPlaying
        let previousRotationByClipID = rotationByClipID

        self.model = model
        self.session = session
        self.clips = nextClips
        self.currentClipID = nextCurrentClipID
        self.isPlaying = model.isPlaying
        self.rotationByClipID = Self.rotationByClipID(for: clips, session: session)
        self.onTapClip = onTapClip

        let nextItems = Self.items(for: clips)
        if previousItems != nextItems {
            applySnapshot(animated: true)
            return
        }

        let itemsToRefresh = itemsNeedingRefresh(
            in: nextItems,
            previousCurrentClipID: previousCurrentClipID,
            previousIsPlaying: previousIsPlaying,
            previousRotationByClipID: previousRotationByClipID
        )
        refreshVisibleCells(matching: Set(itemsToRefresh))
    }

    private func applySnapshot(animated: Bool, reconfigureRetainedItems: Bool = false) {
        let previousItems = Set(dataSource.snapshot().itemIdentifiers)
        let items = Self.items(for: clips)

        var snapshot = NSDiffableDataSourceSnapshot<Int, FilmStripItem>()
        snapshot.appendSections([0])
        snapshot.appendItems(Self.items(for: clips), toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            self?.refreshVisibleCells(matching: nil)
        }
    }

    static func items(for clips: [Clip]) -> [FilmStripItem] {
        var items: [FilmStripItem] = []
        var occurrence: [String: Int] = [:]
        var previousDayKey: String?
        let df = DateFormatter()
        df.dateFormat = "MM.dd"

        for clip in clips {
            let dayKey = df.string(from: clip.capturedAt)
            if dayKey != previousDayKey {
                let occ = occurrence[dayKey, default: 0]
                occurrence[dayKey] = occ + 1
                items.append(.daySprocket(occurrenceIndex: occ, dayKey: dayKey))
                previousDayKey = dayKey
            }
            items.append(.clip(clip.id))
        }
        return items
    }

    private static func rotationByClipID(
        for clips: [Clip],
        session: EditSession
    ) -> [Clip.ID: ClipRotation] {
        Dictionary(uniqueKeysWithValues: clips.map { clip in
            (clip.id, session.rotation(for: clip.id))
        })
    }

    private func itemsNeedingRefresh(
        in items: [FilmStripItem],
        previousCurrentClipID: Clip.ID?,
        previousIsPlaying: Bool,
        previousRotationByClipID: [Clip.ID: ClipRotation]
    ) -> [FilmStripItem] {
        if previousIsPlaying != isPlaying {
            return items
        }

        var clipIDs = Set<Clip.ID>()
        if previousCurrentClipID != currentClipID {
            if let previousCurrentClipID {
                clipIDs.insert(previousCurrentClipID)
            }
            if let currentClipID {
                clipIDs.insert(currentClipID)
            }
        }

        for clip in clips {
            let previousRotation = previousRotationByClipID[clip.id] ?? .r0
            let currentRotation = rotationByClipID[clip.id] ?? .r0
            if previousRotation != currentRotation {
                clipIDs.insert(clip.id)
            }
        }

        let daySprocketNeedsRefresh = isPlaying && previousCurrentClipID != currentClipID
        return items.filter { item in
            switch item {
            case .clip(let id):
                return clipIDs.contains(id)
            case .daySprocket:
                return daySprocketNeedsRefresh
            }
        }
    }

    private func refreshVisibleCells(matching items: Set<FilmStripItem>?) {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let item = dataSource.itemIdentifier(for: indexPath),
                  items?.contains(item) ?? true,
                  let cell = collectionView.cellForItem(at: indexPath) else { continue }

            switch item {
            case .clip(let id):
                configureClipCell(cell, clipID: id)
            case .daySprocket:
                configureDayCell(cell, item: item)
            }
        }
    }

    // MARK: - UICollectionViewDelegate (tap)

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case .clip(let clipID) = item,
              let flat = clips.firstIndex(where: { $0.id == clipID }) else { return }
        let previousClipID = currentClipID
        currentClipID = clipID
        let itemsToRefresh = [previousClipID, currentClipID]
            .compactMap { $0 }
            .map(FilmStripItem.clip)
        refreshVisibleCells(matching: Set(itemsToRefresh))
        onTapClip?(flat)
    }

    // MARK: - UICollectionViewDragDelegate

    func collectionView(_ collectionView: UICollectionView,
                        itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case .clip(let clipID) = item else { return [] }
        let provider = NSItemProvider(object: clipID.uuidString as NSString)
        let dragItem = UIDragItem(itemProvider: provider)
        dragItem.localObject = clipID
        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView,
                        dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let params = UIDragPreviewParameters()
        params.backgroundColor = .clear
        if let cell = collectionView.cellForItem(at: indexPath) {
            params.visiblePath = UIBezierPath(roundedRect: cell.contentView.bounds, cornerRadius: 4)
        }
        return params
    }

    // MARK: - UICollectionViewDropDelegate

    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        // Day sprocket 위로의 drop은 막음 — clip 사이 갭으로만 insert.
        if let dst = destinationIndexPath,
           let item = dataSource.itemIdentifier(for: dst),
           case .daySprocket = item {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func collectionView(_ collectionView: UICollectionView,
                        performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let drop = coordinator.items.first,
              let clipID = drop.dragItem.localObject as? Clip.ID else { return }

        // destination이 nil인 경우 (drop이 collection view 밖에서 끝남) → 끝 슬롯으로.
        let destination = coordinator.destinationIndexPath
            ?? IndexPath(item: max(0, dataSource.snapshot().numberOfItems - 1), section: 0)

        let targetClipIndex = clipsIndex(for: destination)
        guard let from = clips.firstIndex(where: { $0.id == clipID }) else { return }

        // SwiftUI Array.move 의미와 맞추기 — destination이 from보다 뒤면 -1 보정.
        let adjusted = targetClipIndex > from ? targetClipIndex - 1 : targetClipIndex
        let clamped = max(0, min(adjusted, clips.count - 1))
        guard from != clamped else {
            coordinator.drop(drop.dragItem, toItemAt: destination)
            return
        }

        // 1) local clips 즉시 갱신
        let clip = clips.remove(at: from)
        clips.insert(clip, at: clamped)

        // 2) snapshot 동기 적용 — 1프레임 flicker 방지
        applySnapshot(animated: false)

        // 3) SwiftUI model 통보 — onChange(of: model.clips) 가 EditSession 동기화
        model?.move(clipID: clipID, toIndex: clamped)

        // 4) UIKit drop settle 애니메이션
        let newDestination = indexPath(forClipID: clipID) ?? destination
        coordinator.drop(drop.dragItem, toItemAt: newDestination)
    }

    // MARK: - Helpers

    /// IndexPath(섞인 items 기준) → flat clip index 변환.
    private func clipsIndex(for ip: IndexPath) -> Int {
        let snapshot = dataSource.snapshot()
        let allItems = snapshot.itemIdentifiers(inSection: 0)
        var clipCount = 0
        for (idx, item) in allItems.enumerated() {
            if idx >= ip.item { break }
            if case .clip = item { clipCount += 1 }
        }
        return clipCount
    }

    /// flat index → mixed-items IndexPath 역변환.
    private func indexPath(forClipID id: Clip.ID) -> IndexPath? {
        let snapshot = dataSource.snapshot()
        let allItems = snapshot.itemIdentifiers(inSection: 0)
        for (idx, item) in allItems.enumerated() {
            if case .clip(let clipID) = item, clipID == id {
                return IndexPath(item: idx, section: 0)
            }
        }
        return nil
    }

    private func accessibilityLabel(for clip: Clip, index: Int, isCurrent: Bool) -> String {
        let kind = clip.kind == .live ? "라이브 포토" : "비디오"
        let selected = isCurrent ? ", 선택됨" : ""
        return "\(index + 1)번째 클립, \(kind), \(clip.durationSecondsLabel)\(selected)"
    }

    private func moveClipForAccessibility(_ clipID: Clip.ID, by delta: Int) -> Bool {
        guard let from = clips.firstIndex(where: { $0.id == clipID }) else { return false }
        let target = from + delta
        guard clips.indices.contains(target) else { return false }
        model?.move(clipID: clipID, toIndex: target)
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(target + 1)번째 위치로 이동했습니다."
        )
        return true
    }

    /// 폴라로이드 셀의 살짝 회전 — 인덱스 기반 결정적 회전(0/1/2 사이 반복).
    private static func rotationDegrees(forIndex i: Int) -> Double {
        switch i % 3 {
        case 0: return -1
        case 1: return 1
        default: return 0.3
        }
    }
}
