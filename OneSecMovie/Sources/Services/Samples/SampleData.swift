import Foundation
import Models

/// 데모/프리뷰용 샘플 데이터. 실제 PhotoKit 연동 전까지 사용.
public enum SampleData {

    public static let jejuTimeline: [Clip] = {
        let cal = Calendar(identifier: .gregorian)
        let y2025 = DateComponents(calendar: cal, year: 2025, month: 9, day: 14, hour: 9).date!
        let day2 = cal.date(byAdding: .day, value: 1, to: y2025)!

        return [
            // 9/14 · 제주
            Clip(kind: .live,  capturedAt: y2025, duration: 3.0, preset: .jejuSea,    locationNote: "협재 해변"),
            Clip(kind: .video, capturedAt: y2025.addingTimeInterval(300),  duration: 3.0, preset: .jejuOrange, locationNote: "중문 노을"),
            Clip(kind: .live,  capturedAt: y2025.addingTimeInterval(1800), duration: 3.0, preset: .hallasan,   locationNote: "한라산 입구"),

            // 9/15
            Clip(kind: .live,  capturedAt: day2, duration: 3.0, preset: .seoulSun,    locationNote: "소길리 · 오후 4시"),
            Clip(kind: .video, capturedAt: day2.addingTimeInterval(600),  duration: 3.0, preset: .field,      locationNote: "풀밭"),
            Clip(kind: .video, capturedAt: day2.addingTimeInterval(1800), duration: 3.0, preset: .forest,     locationNote: "숲길"),
            Clip(kind: .live,  capturedAt: day2.addingTimeInterval(3600), duration: 3.0, preset: .sunset,     locationNote: "저녁 노을"),
            Clip(kind: .video, capturedAt: day2.addingTimeInterval(5400), duration: 3.0, preset: .cafe,       locationNote: "카페"),
        ]
    }()

    public static let filmTitle = "제주 3일"
    public static let filmTotalDuration: TimeInterval = 84  // 01:24
}

public extension Array where Element == Clip {
    /// "09.14", "09.15" 같은 day-key로 그룹화. 순서를 유지하며 반환.
    func groupedByDay(calendar: Calendar = .init(identifier: .gregorian)) -> [(dayKey: String, clips: [Clip])] {
        var order: [String] = []
        var buckets: [String: [Clip]] = [:]
        let df = DateFormatter()
        df.dateFormat = "MM.dd"
        for clip in self {
            let key = df.string(from: clip.capturedAt)
            if buckets[key] == nil { order.append(key); buckets[key] = [] }
            buckets[key, default: []].append(clip)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }
}
