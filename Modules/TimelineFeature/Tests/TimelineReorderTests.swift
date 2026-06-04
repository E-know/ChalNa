import Foundation
import Testing
import ComposableArchitecture
import Models
@testable import TimelineFeature

@MainActor
struct TimelineReorderTests {

    /// 4번째 클립(idx=3)을 6번째 위치로 이동.
    @Test func testMove_Forward() async {
        let store = testStore()
        let originalIDs = store.state.clips.map(\.id)
        let movingID = store.state.clips[3].id

        await store.send(.clipMoved(id: movingID, toIndex: 6))

        #expect(store.state.clips[6].id == movingID, "이동된 클립이 새 위치(6)에 있어야 함")
        #expect(store.state.clips.count == originalIDs.count, "클립 개수는 변하지 않아야 함")
        #expect(Set(store.state.clips.map(\.id)) == Set(originalIDs), "클립 set은 동일해야 함")
    }

    /// 마지막 → 첫 자리로 이동.
    @Test func testMove_LastToFirst() async {
        let store = testStore()
        let lastID = store.state.clips.last!.id

        await store.send(.clipMoved(id: lastID, toIndex: 0))

        #expect(store.state.clips.first?.id == lastID, "마지막 클립이 첫 자리로 이동해야 함")
    }

    /// 첫 → 마지막 자리로 이동.
    @Test func testMove_FirstToLast() async {
        let store = testStore()
        let firstID = store.state.clips.first!.id
        let lastIndex = store.state.clips.count - 1

        await store.send(.clipMoved(id: firstID, toIndex: lastIndex))

        #expect(store.state.clips.last?.id == firstID, "첫 클립이 마지막 자리로 이동해야 함")
    }

    /// CollectionView drop에서 마지막 셀 뒤 슬롯은 최종 마지막 index로 해석해야 한다.
    @Test func testDropTargetIndex_FirstToTrailingSlot() {
        let count = SampleData.jejuTimeline.count
        let target = FilmStripVC.resolvedDropTargetIndex(
            insertionOffset: count,
            movingFrom: 0,
            clipCount: count
        )

        #expect(target == count - 1, "첫 클립을 마지막 뒤 슬롯에 drop하면 최종 마지막 index가 되어야 함")
    }

    /// 마지막 셀 앞/뒤는 서로 다른 drop 위치다.
    @Test func testDropTargetIndex_DistinguishesBeforeAndAfterLastClip() {
        let count = SampleData.jejuTimeline.count
        let beforeLast = FilmStripVC.resolvedDropTargetIndex(
            insertionOffset: count - 1,
            movingFrom: 0,
            clipCount: count
        )
        let afterLast = FilmStripVC.resolvedDropTargetIndex(
            insertionOffset: count,
            movingFrom: 0,
            clipCount: count
        )

        #expect(beforeLast == count - 2, "마지막 셀 앞 drop은 마지막 바로 앞 index가 되어야 함")
        #expect(afterLast == count - 1, "마지막 셀 뒤 drop은 마지막 index가 되어야 함")
    }

    /// 동일 위치 이동 → no-op.
    @Test func testMove_SameIndex_IsNoOp() async {
        let store = testStore()
        let originalIDs = store.state.clips.map(\.id)
        let movingID = store.state.clips[2].id

        await store.send(.clipMoved(id: movingID, toIndex: 2))

        #expect(store.state.clips.map(\.id) == originalIDs, "동일 위치 이동은 순서를 바꾸지 않아야 함")
    }

    /// 범위 밖 인덱스는 [0, count - 1]로 clamp.
    @Test func testMove_OutOfRange_Clamped() async {
        let store = testStore()
        let movingID = store.state.clips[1].id

        await store.send(.clipMoved(id: movingID, toIndex: 999))
        #expect(store.state.clips.last?.id == movingID, "999는 마지막으로 clamp")

        await store.send(.clipMoved(id: movingID, toIndex: -5))
        #expect(store.state.clips.first?.id == movingID, "음수는 0으로 clamp")
    }

    /// 단일 클립 → no-op (이동할 자리가 없음).
    @Test func testMove_SingleClip_NoOp() async {
        let only = SampleData.jejuTimeline[0]
        let store = testStore(clips: [only])

        await store.send(.clipMoved(id: only.id, toIndex: 0))

        #expect(store.state.clips.count == 1, "여전히 1개")
        #expect(store.state.clips[0].id == only.id, "그대로")
    }

    /// 이동된 클립이 currentIndex였다면 currentIndex가 따라간다.
    @Test func testMove_UpdatesCurrentIndex() async {
        let store = testStore(currentIndex: 3)
        let movingID = store.state.clips[3].id

        await store.send(.clipMoved(id: movingID, toIndex: 6))

        #expect(store.state.currentIndex == 6, "currentIndex가 이동된 클립을 따라가야 함")
        #expect(store.state.clips[6].id == movingID)
    }

    /// 다른 날짜 경계로 옮긴 클립도 FilmStrip 표시 순서가 model.clips 순서를 따라야 한다.
    @Test func testFilmStripItems_PreservesCrossDateMovedOrder() async {
        let store = testStore()
        let dayTwoClipID = store.state.clips[3].id

        await store.send(.clipMoved(id: dayTwoClipID, toIndex: 1))
        let items = FilmStripVC.items(for: store.state.clips)

        let renderedClipIDs = items.compactMap { item -> Clip.ID? in
            guard case .clip(let id) = item else { return nil }
            return id
        }
        let renderedDayKeys = items.compactMap { item -> String? in
            guard case .daySprocket(_, let dayKey) = item else { return nil }
            return dayKey
        }

        #expect(renderedClipIDs == store.state.clips.map(\.id), "표시용 clip 순서가 편집 모델 순서와 같아야 함")
        #expect(renderedDayKeys == ["09.14", "09.15", "09.14", "09.15"], "같은 날짜라도 비연속 구간이면 구분자를 다시 표시해야 함")
    }

    private func testStore(
        clips: [Clip] = SampleData.jejuTimeline,
        currentIndex: Int = 0
    ) -> TestStoreOf<TimelineFeature> {
        let store = TestStore(
            initialState: TimelineFeature.State(clips: clips, currentIndex: currentIndex)
        ) {
            TimelineFeature()
        }
        store.exhaustivity = .off
        return store
    }
}
