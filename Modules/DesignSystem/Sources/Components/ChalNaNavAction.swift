import SwiftUI

/// 헤더 좌·우 액션. **호출처가 글리프 크기를 지정할 수 없다** —
/// 같은 바에서 10pt chevron 과 33pt X 가 공존했던 문제를 구조적으로 막는다.
///
/// 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §5.1
public struct ChalNaNavAction: View {

    /// 모든 아이콘 액션의 글리프 크기. 개별 조정 불가.
    private static let glyph: CGFloat = 20
    /// HIG 최소 터치 영역.
    private static let hit: CGFloat = 44

    private enum Kind {
        case icon(ChalNaIconKind)
        case text(LocalizedStringKey)
        case empty
    }

    private let kind: Kind
    private let action: () -> Void
    private let label: LocalizedStringKey?

    private init(kind: Kind, label: LocalizedStringKey?, action: @escaping () -> Void) {
        self.kind = kind
        self.label = label
        self.action = action
    }

    // MARK: - Factories

    public static func back(action: @escaping () -> Void) -> ChalNaNavAction {
        .init(kind: .icon(.chevronLeft), label: "뒤로", action: action)
    }

    public static func close(action: @escaping () -> Void) -> ChalNaNavAction {
        .init(kind: .icon(.close), label: "닫기", action: action)
    }
    // 주의: "닫기" 는 Localizable.xcstrings 에 아직 en/ja 번역이 없다(사전 확인 완료).
    // Step 6 에서 번역을 추가한다. "뒤로" 는 이미 Back/戻る 가 있다.

    public static func icon(
        _ kind: ChalNaIconKind,
        accessibilityLabel: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> ChalNaNavAction {
        .init(kind: .icon(kind), label: accessibilityLabel, action: action)
    }

    /// 우측 텍스트 액션("완료"/"저장"). accent 색 + headline.
    public static func text(_ title: LocalizedStringKey, action: @escaping () -> Void) -> ChalNaNavAction {
        .init(kind: .text(title), label: title, action: action)
    }

    public static var empty: ChalNaNavAction {
        .init(kind: .empty, label: nil, action: {})
    }

    // MARK: - Body

    public var body: some View {
        switch kind {
        case .empty:
            Color.clear.frame(width: Self.hit, height: Self.hit)
        case .icon(let iconKind):
            button {
                ChalNaIcon(iconKind, size: Self.glyph, weight: .semibold)
                    .foregroundColor(ChalNaColor.textPrimary)
            }
        case .text(let title):
            button {
                Text(title)
                    .font(ChalNaTypography.headline)
                    .foregroundColor(ChalNaColor.accent)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func button<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 8)
                .frame(minWidth: Self.hit, minHeight: Self.hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(NavActionPressStyle())
        .accessibilityLabel(label ?? "")
    }
}

private struct NavActionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1)
            .animation(ChalNaMotion.fast, value: configuration.isPressed)
    }
}
