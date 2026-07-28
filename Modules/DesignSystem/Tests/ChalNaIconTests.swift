import Testing
import SwiftUI
import UIKit
import DesignSystem

/// 모든 아이콘이 실제 존재하는 SF Symbol 에 매핑되는지 검증한다.
/// 오타난 심볼 이름은 런타임에 조용히 빈 이미지가 되므로 컴파일로는 잡히지 않는다.
struct ChalNaIconTests {

    @Test func testEveryKindMapsToExistingSystemSymbol() {
        for kind in ChalNaIconKind.allCases {
            let name = kind.systemName
            #expect(!name.isEmpty, "\(kind.rawValue) 의 systemName 이 비었다")
            #expect(UIImage(systemName: name) != nil,
                    "\(kind.rawValue) → \"\(name)\" 심볼이 이 OS 에 없다")
        }
    }

    @Test func testNoTwoKindsShareTheSameSymbol() {
        var seen: [String: ChalNaIconKind] = [:]
        for kind in ChalNaIconKind.allCases {
            let name = kind.systemName
            if let previous = seen[name] {
                Issue.record("\(kind.rawValue) 와 \(previous.rawValue) 가 같은 심볼 \"\(name)\" 을 쓴다")
            }
            seen[name] = kind
        }
    }

    /// 화면에서 쓰이는 종류가 전부 정의돼 있는지 — 누락되면 컴파일 에러로 잡히지만
    /// 이 테스트는 '왜 필요한지'를 문서화한다.
    @Test func testRequiredKindsExist() {
        let required: [ChalNaIconKind] = [
            .play, .pause, .plus, .share, .download, .film,
            .chevronLeft, .chevronRight, .close, .check,
            .skipBack, .skipForward, .trash, .move, .rotate, .textLabel,
            .settings, .livePhoto, .video,
        ]
        for kind in required {
            #expect(ChalNaIconKind.allCases.contains(kind), "\(kind.rawValue) 누락")
        }
    }
}
