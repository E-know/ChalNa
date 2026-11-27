import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem
import UIKit

enum FilmStripLayout { case strip, list, grid }

// MARK: - SwiftUI bridge

/// `UICollectionView` 기반 FilmStrip 의 SwiftUI 진입점. TimelineFeature store 기반.
struct FilmStripCollectionView: UIViewControllerRepresentable {
    let store: StoreOf<TimelineFeature>
    let session: EditSession
    let layout: FilmStripLayout
    let onTapClip: (Int) -> Void

    func makeUIViewController(context: Context) -> FilmStripVC {
        FilmStripVC()
    }

    func updateUIViewController(_ vc: FilmStripVC, context: Context) {
        vc.update(
            clips: store.clips,
            currentIndex: store.currentIndex,
            layout: layout,
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
    private var layout: FilmStripLayout = .strip
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
        collectionView.backgroundColor = UIColor(ChalNaColor.bg)
        collectionView.showsVerticalScrollIndicator = false
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
        let mode = layout
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = mode == .strip ? .horizontal : .vertical
        return UICollectionViewCompositionalLayout(sectionProvider: { _, environment in
            let height: CGFloat = mode == .strip ? 74 : 82
            let width = environment.container.effectiveContentSize.width
            let groupWidth: NSCollectionLayoutDimension = mode == .strip
                ? .absolute(max(64, (width - 18) / 4)) : .fractionalWidth(1)
            let itemWidth: NSCollectionLayoutDimension = mode == .grid
                ? .absolute(max(1, (width - 12) / 2)) : .fractionalWidth(1)
            let size = NSCollectionLayoutSize(widthDimension: itemWidth, heightDimension: .absolute(height))
            let item = NSCollectionLayoutItem(layoutSize: size)
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: groupWidth, heightDimension: .absolute(height)),
                subitems: mode == .grid ? [item, item] : [item]
            )
            group.interItemSpacing = .fixed(12)
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = mode == .strip ? 6 : 0
            return section
        }, configuration: config)
    }

    // MARK: - Cell configuration

    private func configureClipCell(_ cell: UICollectionViewCell, clipID: Clip.ID) {
        guard let clip = clips.first(where: { $0.id == clipID }) else { return }
        let userRotation = session?.rotation(for: clipID) ?? .r0
        let isCurrent = clipID == currentClipID
        let flatIndex = clips.firstIndex(where: { $0.id == clipID }) ?? 0
        let mode = layout
        let name = clip.locationNote ?? LabelText.timeString(clip.capturedAt)
        cell.contentConfiguration = UIHostingConfiguration {
            if mode == .strip {
                VStack(alignment: .leading, spacing: 3) {
                    GeometryReader { proxy in
                        RotatableContent(rotation: userRotation) { clip.thumbnailView() }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .overlay(alignment: .topTrailing) {
                                if isCurrent {
                                    ChalNaIcon(.reorderLines, size: 12)
                                        .foregroundStyle(ChalNaColor.onMedia)
                                        .padding(4)
                                        .background(ChalNaColor.scrim, in: RoundedRectangle(cornerRadius: ChalNaRadius.xs))
                                        .padding(2)
                                }
                            }
                            .overlay(alignment: .bottom) {
                                if isCurrent { Rectangle().fill(ChalNaColor.accent).frame(height: 3) }
                            }
                    }
                    .frame(height: 46)
                    Text(clip.durationSecondsLabel)
                        .font(ChalNaTypography.caption)
                        .foregroundStyle(isCurrent ? ChalNaColor.accent : ChalNaColor.textSecondary)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                HStack(spacing: 10) {
                    RotatableContent(rotation: userRotation) { clip.thumbnailView() }
                        .frame(width: 52, height: 52).clipped()
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: "\(flatIndex + 1). \(name)")
                            .font(ChalNaTypography.body)
                            .lineLimit(1)
                            .foregroundStyle(isCurrent ? ChalNaColor.accent : ChalNaColor.textPrimary)
                        Text(clip.durationSecondsLabel)
                            .font(ChalNaTypography.caption).foregroundStyle(ChalNaColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                    ChalNaIcon(.reorderLines, size: 15).foregroundStyle(ChalNaColor.textSecondary)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isCurrent ? ChalNaColor.selection : ChalNaColor.bg)
                .overlay(alignment: .leading) {
                    if isCurrent { Rectangle().fill(ChalNaColor.accent).frame(width: 3) }
                }
                .overlay(alignment: .bottom) { Rectangle().fill(ChalNaColor.border).frame(height: 1) }
            }
        }
        .margins(.all, 0)
        cell.accessibilityIdentifier = "timeline.clip.\(flatIndex)"
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = accessibilityLabel(for: clip, index: flatIndex, isCurrent: isCurrent)
        cell.accessibilityHint = String(localized: "선택하려면 두 번 탭하고, 순서를 바꾸려면 사용자 동작을 사용하세요.", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        var traits: UIAccessibilityTraits = [.button]
        if isCurrent { traits.insert(.selected) }
        cell.accessibilityTraits = traits
        cell.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: String(localized: "앞으로 이동", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) { [weak self] _ in
                self?.moveClipForAccessibility(clipID, by: -1) ?? false
            },
            UIAccessibilityCustomAction(name: String(localized: "뒤로 이동", bundle: AppLocalization.bundle, locale: AppLocalization.locale)) { [weak self] _ in
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
        cell.accessibilityLabel = String(localized: "\(dayKey) 촬영일", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
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
        layout: FilmStripLayout,
        isPlaying: Bool,
        session: EditSession,
        onTapClip: @escaping (Int) -> Void,
        onMove: @escaping (Clip.ID, Int) -> Void
    ) {
        let layoutChanged = self.layout != layout
        if layoutChanged {
            self.layout = layout
            collectionView.setCollectionViewLayout(makeLayout(), animated: false)
        }
        let previousItems = dataSource.snapshot().itemIdentifiers
        let previousCurrentClipID = currentClipID
        let previousIsPlaying = self.isPlaying
        let previousRotationByClipID = rotationByClipID
        let previousClips = self.clips
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
            var insertedSelection: FilmStripItem?
            if previousCurrentClipID != nil, let nextCurrentClipID, !previousItems.contains(.clip(nextCurrentClipID)) {
                insertedSelection = .clip(nextCurrentClipID)
            }
            applySnapshot(animated: true, revealing: insertedSelection)
            return
        }

        var itemsToRefresh = itemsNeedingRefresh(
            in: nextItems,
            previousCurrentClipID: previousCurrentClipID,
            previousIsPlaying: previousIsPlaying,
            previousRotationByClipID: previousRotationByClipID
        )
        for (old, new) in zip(previousClips, nextClips) where old.trimRange != new.trimRange {
            itemsToRefresh.append(.clip(new.id))
        }
        refreshVisibleCells(matching: layoutChanged ? nil : Set(itemsToRefresh))
    }

    private func applySnapshot(animated: Bool, revealing item: FilmStripItem? = nil) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, FilmStripItem>()
        snapshot.appendSections([0])
        snapshot.appendItems(Self.items(for: clips), toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            guard let self else { return }
            refreshVisibleCells(matching: nil)
            guard let item, let currentClipID, item == .clip(currentClipID),
                  let indexPath = dataSource.indexPath(for: item) else { return }
            collectionView.layoutIfNeeded()
            if let attributes = collectionView.layoutAttributesForItem(at: indexPath),
               !collectionView.bounds.contains(attributes.frame) {
                let position: UICollectionView.ScrollPosition = layout == .strip ? .centeredHorizontally : .centeredVertically
                collectionView.scrollToItem(at: indexPath, at: position, animated: animated)
            }
        }
    }

    static func items(for clips: [Clip]) -> [FilmStripItem] {
        if let first = clips.first,
           clips.allSatisfy({ Calendar.current.isDate($0.capturedAt, inSameDayAs: first.capturedAt) }) {
            return clips.map { .clip($0.id) }
        }
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
            params.visiblePath = UIBezierPath(roundedRect: cell.contentView.bounds,
                                              cornerRadius: ChalNaRadius.xs)
        }
        return params
    }

    // MARK: - UICollectionViewDropDelegate

    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
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

        // 3) 리듀서가 순서를 확정하고 EditSession에 반영한다.
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
        let after = layout == .list ? dropLocation.y > attributes.frame.midY : dropLocation.x > attributes.frame.midX
        return after ? clipCount + 1 : clipCount
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
        let kind = clip.kind == .live ? String(localized: "라이브 포토", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : String(localized: "비디오", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        let selected = isCurrent ? String(localized: ", 선택됨", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : ""
        return String(localized: "\(index + 1)번째 클립, \(kind), \(clip.durationSecondsLabel)\(selected)", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    private func moveClipForAccessibility(_ clipID: Clip.ID, by delta: Int) -> Bool {
        guard let from = clips.firstIndex(where: { $0.id == clipID }) else { return false }
        let target = from + delta
        guard clips.indices.contains(target) else { return false }
        onMove?(clipID, target)
        UIAccessibility.post(
            notification: .announcement,
            argument: String(localized: "\(target + 1)번째 위치로 이동했습니다.", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        )
        return true
    }

}
