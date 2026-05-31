import Foundation

/// 앱에서 트래킹하는 사용자 활성화 funnel 이벤트 정의.
/// 이름은 Firebase Analytics 권장 형식(snake_case, 40자 이내)을 따른다.
public enum AnalyticsEvent: Sendable, Equatable {
    // 진입 / 화면
    case homeViewed
    case newVlogTapped
    case mediaPickerOpened(source: MediaPickerSourceTag)
    case timelineOpened
    case exportScreenOpened
    case filmDetailOpened(filmID: UUID)

    // 미디어 선택 funnel
    case clipsConfirmed(count: Int)

    // Export funnel
    case exportStarted(clipCount: Int)
    case exportCompleted(durationMs: Int?)
    case exportFailed(reason: String)

    // 저장 / 공유
    case vlogSavedToLibrary
    case vlogSaveFailed(reason: String)

    // 라이브러리
    case filmDeleted(filmID: UUID)

    // 설정 / 라벨
    case settingsOpened
    case labelToggled(kind: String, on: Bool)
    case labelPositionChanged(kind: String, position: Int)

    // 문의 / 신고
    case feedbackSubmitted(category: String)
    case feedbackSendFailed(reason: String)

    /// Firebase Analytics 에 보낼 이벤트 이름 (snake_case).
    public var name: String {
        switch self {
        case .homeViewed:          return "home_viewed"
        case .newVlogTapped:       return "new_vlog_tapped"
        case .mediaPickerOpened:   return "media_picker_opened"
        case .timelineOpened:      return "timeline_opened"
        case .exportScreenOpened:  return "export_screen_opened"
        case .filmDetailOpened:    return "film_detail_opened"
        case .clipsConfirmed:      return "clips_confirmed"
        case .exportStarted:       return "export_started"
        case .exportCompleted:     return "export_completed"
        case .exportFailed:        return "export_failed"
        case .vlogSavedToLibrary:  return "vlog_saved_to_library"
        case .vlogSaveFailed:      return "vlog_save_failed"
        case .filmDeleted:         return "film_deleted"
        case .settingsOpened:        return "settings_opened"
        case .labelToggled:          return "label_toggled"
        case .labelPositionChanged:  return "label_position_changed"
        case .feedbackSubmitted:     return "feedback_submitted"
        case .feedbackSendFailed:    return "feedback_send_failed"
        }
    }

    /// Firebase Analytics 파라미터 (Sendable primitives 만 허용).
    public var parameters: [String: AnalyticsParameterValue] {
        switch self {
        case .homeViewed, .newVlogTapped, .timelineOpened, .exportScreenOpened, .vlogSavedToLibrary, .settingsOpened:
            return [:]
        case let .mediaPickerOpened(source):
            return ["source": .string(source.rawValue)]
        case let .clipsConfirmed(count):
            return ["count": .int(count)]
        case let .exportStarted(clipCount):
            return ["clip_count": .int(clipCount)]
        case let .exportCompleted(durationMs):
            guard let ms = durationMs else { return [:] }
            return ["duration_ms": .int(ms)]
        case let .exportFailed(reason):
            return ["reason": .string(reason)]
        case let .vlogSaveFailed(reason):
            return ["reason": .string(reason)]
        case let .filmDetailOpened(filmID):
            return ["film_id": .string(filmID.uuidString)]
        case let .filmDeleted(filmID):
            return ["film_id": .string(filmID.uuidString)]
        case let .labelToggled(kind, on):
            return ["kind": .string(kind), "on": .bool(on)]
        case let .labelPositionChanged(kind, position):
            return ["kind": .string(kind), "position": .int(position)]
        case let .feedbackSubmitted(category):
            return ["category": .string(category)]
        case let .feedbackSendFailed(reason):
            return ["reason": .string(reason)]
        }
    }
}

public enum MediaPickerSourceTag: String, Sendable {
    case photoLibrary = "photo_library"
    case devFixtures = "dev_fixtures"
}

/// Analytics 파라미터에 허용되는 primitive value.
public enum AnalyticsParameterValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}
