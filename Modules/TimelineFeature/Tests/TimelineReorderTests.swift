import Foundation
import Testing
import Models
import TimelineFeature

struct TimelineReorderTests {

    /// 4번째 클립(idx=3)을 6번째 위치로 이동.
    @Test func testMove_Forward() {
        let model = TimelineModel(clips: SampleData.jejuTimeline)
        let originalIDs = model.clips.map(\.id)
        let movingID = model.clips[3].id

        model.move(clipID: movingID, toIndex: 6)

        #expect(model.clips[6].id == movingID, "이동된 클립이 새 위치(6)에 있어야 함")
        #expect(model.clips.count == originalIDs.count, "클립 개수는 변하지 않아야 함")
        #expect(Set(model.clips.map(\.id)) == Set(originalIDs), "클립 set은 동일해야 함")
    }

    /// 마지막 → 첫 자리로 이동.
    @Test func testMove_LastToFirst() {
        let model = TimelineModel(clips: SampleData.jejuTimeline)
        let lastID = model.clips.last!.id

        model.move(clipID: lastID, toIndex: 0)

        #expect(model.clips.first?.id == lastID, "마지막 클립이 첫 자리로 이동해야 함")
    }

    /// 첫 → 마지막 자리로 이동.
    @Test func testMove_FirstToLast() {
        let model = TimelineModel(clips: SampleData.jejuTimeline)
        let firstID = model.clips.first!.id
        let lastIndex = model.clips.count - 1

        model.move(clipID: firstID, toIndex: lastIndex)

        #expect(model.clips.last?.id == firstID, "첫 클립이 마지막 자리로 이동해야 함")
    }

    /// 동일 위치 이동 → no-op.
    @Test func testMove_SameIndex_IsNoOp() {
        let model = TimelineModel(clips: SampleData.jejuTimeline)
        let originalIDs = model.clips.map(\.id)
        let movingID = model.clips[2].id

        model.move(clipID: movingID, toIndex: 2)

        #expect(model.clips.map(\.id) == originalIDs, "동일 위치 이동은 순서를 바꾸지 않아야 함")
    }

    /// 범위 밖 인덱스는 [0, count - 1]로 clamp.
    @Test func testMove_OutOfRange_Clamped() {
        let model = TimelineModel(clips: SampleData.jejuTimeline)
        let movingID = model.clips[1].id

        model.move(clipID: movingID, toIndex: 999)
        #expect(model.clips.last?.id == movingID, "999는 마지막으로 clamp")

        model.move(clipID: movingID, toIndex: -5)
        #expect(model.clips.first?.id == movingID, "음수는 0으로 clamp")
    }

    /// 단일 클립 → no-op (이동할 자리가 없음).
    @Test func testMove_SingleClip_NoOp() {
        let only = SampleData.jejuTimeline[0]
        let model = TimelineModel(clips: [only])

        model.move(clipID: only.id, toIndex: 0)

        #expect(model.clips.count == 1, "여전히 1개")
        #expect(model.clips[0].id == only.id, "그대로")
    }

    /// 이동된 클립이 currentIndex였다면 currentIndex가 따라간다.
    @Test func testMove_UpdatesCurrentIndex() {
        let model = TimelineModel(clips: SampleData.jejuTimeline, currentIndex: 3)
        let movingID = model.clips[3].id

        model.move(clipID: movingID, toIndex: 6)

        #expect(model.currentIndex == 6, "currentIndex가 이동된 클립을 따라가야 함")
        #expect(model.clips[6].id == movingID)
    }
}
