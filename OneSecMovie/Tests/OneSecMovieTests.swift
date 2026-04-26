import Foundation
import CompositionService
import Models
import CoreGraphics
import Testing
@testable import OneSecMovie

struct ClipRotationTests {

    @Test func testNextCyclesThroughFourSteps() {
        var r: ClipRotation = .r0
        r = r.next()
        #expect(r == .r90)
        r = r.next()
        #expect(r == .r180)
        r = r.next()
        #expect(r == .r270)
        r = r.next()
        #expect(r == .r0, "4번 next() 후에는 원위치여야 한다")
    }

    @Test func testSwapsAxes() {
        #expect(ClipRotation.r0.swapsAxes == false)
        #expect(ClipRotation.r180.swapsAxes == false)
        #expect(ClipRotation.r90.swapsAxes == true)
        #expect(ClipRotation.r270.swapsAxes == true)
    }

    @Test func testEditSessionCycleRotation() {
        let session = EditSession()
        let id = UUID()
        #expect(session.rotation(for: id) == .r0, "기본값은 r0")
        session.cycleRotation(for: id)
        #expect(session.rotation(for: id) == .r90)
        session.cycleRotation(for: id)
        session.cycleRotation(for: id)
        session.cycleRotation(for: id)
        #expect(session.rotation(for: id) == .r0, "4번 cycle 후 원위치")
    }
}

struct CompositionTransformTests {

    /// r0: 가로 1920×1080 클립이 1080×1080 renderSize에 가운데 정렬되어야 한다.
    @Test func testTransform_R0_GivesCenteredIdentity() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1080)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r0,
            renderSize: render
        )
        // 원점에 (0,0)을 넣었을 때 가운데로 가는 translation이어야 한다.
        let origin = CGPoint(x: 0, y: 0).applying(t)
        #expect(abs(origin.x - (render.width - natural.width) / 2) < 0.001)
        #expect(abs(origin.y - (render.height - natural.height) / 2) < 0.001)
    }

    /// r90: 가로 1920×1080 클립이 r90 회전 후 1080×1920로 swap되고
    /// renderSize 1080×1920에 가운데 정렬되어야 한다 (정확히 꽉 참).
    @Test func testTransform_R90_FillsRotatedCanvas() {
        let natural = CGSize(width: 1920, height: 1080)
        let render = CGSize(width: 1080, height: 1920)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r90,
            renderSize: render
        )
        // 원본 사각형 (0,0)-(1920,1080) 의 네 모서리가 transform 후 모두 renderRect 안에 들어가야 한다.
        let renderRect = CGRect(origin: .zero, size: render)
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: natural.width, y: 0),
            CGPoint(x: 0, y: natural.height),
            CGPoint(x: natural.width, y: natural.height)
        ]
        for c in corners {
            let mapped = c.applying(t)
            // 작은 부동소수점 오차 허용.
            #expect(mapped.x >= renderRect.minX - 0.5 && mapped.x <= renderRect.maxX + 0.5,
                    "r90 매핑된 모서리가 render width 안에 있어야 함: \(mapped.x)")
            #expect(mapped.y >= renderRect.minY - 0.5 && mapped.y <= renderRect.maxY + 0.5,
                    "r90 매핑된 모서리가 render height 안에 있어야 함: \(mapped.y)")
        }
    }

    /// r180: 사이즈 swap 없이 가운데 정렬, 180° 뒤집힘.
    @Test func testTransform_R180_KeepsAxesButFlips() {
        let natural = CGSize(width: 1080, height: 1080)
        let render = CGSize(width: 1080, height: 1080)
        let t = AVFoundationCompositionService.transform(
            naturalSize: natural,
            preferredTransform: .identity,
            rotation: .r180,
            renderSize: render
        )
        // 원본 (0,0) 모서리는 r180 후 (1080,1080) 근처 — 즉 renderRect의 우하단.
        let mapped = CGPoint(x: 0, y: 0).applying(t)
        #expect(abs(mapped.x - render.width) < 0.5)
        #expect(abs(mapped.y - render.height) < 0.5)
    }
}

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

        // 999 → 마지막 자리로
        model.move(clipID: movingID, toIndex: 999)
        #expect(model.clips.last?.id == movingID, "999는 마지막으로 clamp")

        // -5 → 첫 자리로
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

struct TimelinePlaybackTests {
    
    /// Test A: Verify that currentIndex auto-advances during simulated playback
    @Test func testAdvancePlayheadSimulated_UpdatesCurrentIndex() async throws {
        // Arrange: Create a timeline with sample data (8 clips × 3sec each)
        let model = TimelineModel(
            title: "Test Film",
            clips: SampleData.jejuTimeline,
            currentIndex: 0,
            state: .idle
        )
        
        #expect(model.clips.count == 8)
        #expect(model.currentIndex == 0, "Should start at clip 0")
        #expect(model.playheadSeconds == 0, "Should start at 0 seconds")
        
        // Act: Start playback
        model.togglePlay()
        #expect(model.isPlaying, "Model should be in playing state")
        
        // Spawn the async playhead advancement
        let advanceTask = Task {
            await model.advancePlayheadSimulated()
        }
        
        // Wait for first clip boundary (3 seconds)
        try? await Task.sleep(nanoseconds: UInt64(3.5 * 1_000_000_000))
        
        // Assert: After 3.5 seconds, playhead should have crossed into clip 1
        #expect(model.currentIndex == 1, "Should advance to clip 1 after ~3 seconds")
        #expect(model.playheadSeconds > 3.0, "Playhead should be past 3 seconds")
        
        // Wait for second clip boundary (3 more seconds = 6.5 total)
        try? await Task.sleep(nanoseconds: UInt64(3.5 * 1_000_000_000))
        
        // Assert: After 6.5 seconds, playhead should be in clip 2
        #expect(model.currentIndex == 2, "Should advance to clip 2 after ~6 seconds")
        #expect(model.playheadSeconds > 6.0, "Playhead should be past 6 seconds")
        
        // Cleanup
        model.togglePlay()
        try? await Task.sleep(nanoseconds: 500_000_000)
        advanceTask.cancel()
    }
    
    /// Test B: Verify export service responds appropriately when no video clips are available
    @Test func testExportFlow_HandlesNoVideoError() async throws {
        // Arrange: Sample data has no actual videoURL (nil for all)
        let clips = SampleData.jejuTimeline
        #expect(!clips.isEmpty, "Should have sample clips")
        #expect(clips.allSatisfy { $0.videoURL == nil }, "Sample clips should have no videoURL")
        
        // Act: Create export service and attempt export with video-less clips
        let service = AVFoundationCompositionService()
        var finalError: String? = nil
        var progressEvents: Int = 0
        
        for await event in service.export(clips: clips) {
            switch event {
            case .progress:
                progressEvents += 1
            case .completed:
                // Should not reach here since no video data
                break
            case .failed(let msg):
                finalError = msg
            }
        }
        
        // Assert: Should fail gracefully with meaningful error
        #expect(finalError != nil, "Should report error when no video is available")
        #expect(finalError?.contains("영상") ?? false || finalError?.contains("video") ?? false, 
                "Error message should mention missing video")
        #expect(progressEvents == 0, "Should not produce progress events when no video available")
    }
}
