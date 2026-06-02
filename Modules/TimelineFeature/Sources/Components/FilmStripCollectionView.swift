import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem
import UIKit

// MARK: - SwiftUI bridge

/// `UICollectionView` 기반 FilmStrip 의 SwiftUI 진입점. TimelineFeature store 기반.
struct FilmStripCollectionView: UIViewControllerRepresentable {
    let store: StoreOf<TimelineFeature>
    let session: EditSession
    let onTapClip: (Int) -> Void

    func makeUIViewController(context: Context) -> FilmStripVC {
        FilmStripVC()
    }

    func updateUIViewController(_ vc: FilmStripVC, context: Context) {
        vc.update(
            clips: store.clips,
            currentIndex: store.currentIndex,
            isPlaying: store.isPlaying,
            session: session,
            onTapClip: onTapClip,
            onMove: { id, target in store.send(.clipMoved(id: id, toIndex: target)) }
        )
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
    private weak var session: EditSession?
    private var currentClipID: Clip.ID?
    private var isPlaying: Bool = false
    private var rotationByClipID: [Clip.ID: ClipRotation] = [:]
    private var onTapClip: ((Int) -> Void)?
    private var onMove: ((Clip.ID, Int) -> Void)?

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
        collectionView.backgroundColor = UIColor(named: "ChalNaInk") ?? .black
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
                    .font(ChalNaTypography.monoFallback(9, weight: .medium))
                    .foregroundColor(visualState == .selected || visualState == .playing
                        ? ChalNaColor.coral
                        : ChalNaColor.white.opacity(0.7))
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

    func update(
        clips: [Clip],
        currentIndex: Int,
        isPlaying: Bool,
        session: EditSession,
        onTapClip: @escaping (Int) -> Void,
        onMove: @escaping (Clip.ID, Int) -> Void
    ) {
        let previousItems = dataSource.snapshot().itemIdentifiers
        let previousCurrentClipID = currentClipID
        let previousIsPlaying = self.isPlaying
        let previousRotationByClipID = rotationByClipID
        let nextClips = clips
        let nextCurrentClipID = nextClips.indices.contains(currentIndex) ? nextClips[currentIndex].id : nil
        let nextItems = Self.items(for: nextClips)

        self.session = session
        self.clips = nextClips
        self.currentClipID = nextCurrentClipID
        self.isPlaying = isPlaying
        self.rotationByClipID = Self.rotationByClipID(for: nextClips, session: session)
        self.onTapClip = onTapClip
        self.onMove = onMove

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

    private func applySnapshot(animated: Bool) {
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

        guard let from = clips.firstIndex(where: { $0.id == clipID }) else { return }
        let insertionOffset = clipInsertionOffset(
            for: coordinator.destinationIndexPath,
            dropLocation: coordinator.session.location(in: collectionView)
        )

        guard let target = Self.resolvedDropTargetIndex(
            insertionOffset: insertionOffset,
            movingFrom: from,
            clipCount: clips.count
        ) else { return }
        let currentDestination = indexPath(forClipID: clipID)
            ?? coordinator.destinationIndexPath
            ?? IndexPath(item: max(0, dataSource.snapshot().numberOfItems - 1), section: 0)
        guard from != target else {
            coordinator.drop(drop.dragItem, toItemAt: currentDestination)
            return
        }

        // 1) local clips 즉시 갱신
        let clip = clips.remove(at: from)
        clips.insert(clip, at: target)

        // 2) snapshot 동기 적용 — 1프레임 flicker 방지
        applySnapshot(animated: false)

        // 3) Reducer 에 통보 — store 가 clips 를 갱신하고 onChange(of: store.clips) 가 EditSession 동기화
        onMove?(clipID, target)

        // 4) UIKit drop settle 애니메이션
        let fallbackDestination = coordinator.destinationIndexPath ?? currentDestination
        let newDestination = indexPath(forClipID: clipID) ?? fallbackDestination
        coordinator.drop(drop.dragItem, toItemAt: newDestination)
    }

    // MARK: - Helpers

    /// Drop 위치를 원본 clips 배열 기준 insertion offset(0...count)으로 변환.
    private func clipInsertionOffset(for destination: IndexPath?, dropLocation: CGPoint) -> Int {
        guard let destination else { return clips.count }

        let snapshot = dataSource.snapshot()
        let allItems = snapshot.itemIdentifiers(inSection: 0)
        guard destination.item < allItems.count else { return clips.count }

        var clipCount = 0
        for (idx, item) in allItems.enumerated() {
            if idx >= destination.item { break }
            if case .clip = item { clipCount += 1 }
        }

        guard case .clip = allItems[destination.item] else { return clipCount }
        let itemIndexPath = IndexPath(item: destination.item, section: destination.section)
        guard let attributes = collectionView.layoutAttributesForItem(at: itemIndexPath) else {
            return clipCount
        }
        return dropLocation.x > attributes.frame.midX ? clipCount + 1 : clipCount
    }

    /// 원본 배열 기준 insertion offset을 remove 이후 최종 index로 변환.
    static func resolvedDropTargetIndex(
        insertionOffset: Int,
        movingFrom sourceIndex: Int,
        clipCount: Int
    ) -> Int? {
        guard clipCount > 0, (0..<clipCount).contains(sourceIndex) else { return nil }
        let boundedOffset = max(0, min(insertionOffset, clipCount))
        let adjustedIndex = boundedOffset > sourceIndex ? boundedOffset - 1 : boundedOffset
        return max(0, min(adjustedIndex, clipCount - 1))
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
        onMove?(clipID, target)
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
