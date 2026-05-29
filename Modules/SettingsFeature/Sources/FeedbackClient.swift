import Foundation
import ComposableArchitecture

/// 신고를 외부(텔레그램 봇)로 전송하는 클라이언트. liveValue 가 URLSession 으로 sendMessage POST.
@DependencyClient
public struct FeedbackClient: Sendable {
    public var send: @Sendable (FeedbackReport) async throws -> Void
}

extension FeedbackClient: DependencyKey {
    public static let liveValue = FeedbackClient(
        send: { report in
            try await TelegramSender.send(text: report.telegramMessageText)
        }
    )

    public static let testValue = FeedbackClient()
}

public extension DependencyValues {
    var feedbackClient: FeedbackClient {
        get { self[FeedbackClient.self] }
        set { self[FeedbackClient.self] = newValue }
    }
}

/// 신고 전송 실패 도메인 에러. 사용자 표시 메시지는 errorDescription.
public enum FeedbackError: LocalizedError {
    case network(Error)
    case telegram(description: String)

    public var errorDescription: String? {
        switch self {
        case .network:
            return "전송에 실패했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
        case .telegram:
            return "전송에 실패했어요. 잠시 후 다시 시도해 주세요."
        }
    }
}

/// 텔레그램 봇 수신 설정. 토큰은 클라이언트에 내장(앱에 백엔드가 없어 수용한 트레이드오프).
private enum TelegramConfig {
    static let token = "8878495180:AAEmWIDLTSjkC3MOgz3jh5VkHFTJXpMtm5c"
    static let chatID: Int64 = 7298669942
}

/// 텔레그램 sendMessage 호출. JSON 바디로 보내 사용자 입력 이스케이프 이슈를 피한다.
private enum TelegramSender {
    private struct Payload: Encodable {
        let chat_id: Int64
        let text: String
    }

    private struct APIResponse: Decodable {
        let ok: Bool
        let description: String?
    }

    static func send(text: String) async throws {
        guard let url = URL(string: "https://api.telegram.org/bot\(TelegramConfig.token)/sendMessage") else {
            throw FeedbackError.telegram(description: "invalid url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(Payload(chat_id: TelegramConfig.chatID, text: text))
        } catch {
            throw FeedbackError.telegram(description: "failed to encode payload")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FeedbackError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FeedbackError.telegram(description: "no http response")
        }
        let decoded = try? JSONDecoder().decode(APIResponse.self, from: data)
        guard http.statusCode == 200, decoded?.ok == true else {
            throw FeedbackError.telegram(description: decoded?.description ?? "HTTP \(http.statusCode)")
        }
    }
}
