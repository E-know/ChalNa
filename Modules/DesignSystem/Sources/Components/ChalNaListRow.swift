import SwiftUI

/// 설정류 리스트 행. Settings · LabelSettings · Language 가 각자 손으로 쓰던
/// 행 빌더 4개를 대체한다. 최소 높이·터치 영역·비활성 톤이 여기서만 결정된다.
///
/// **고정 높이가 아니라 `minHeight`** 다 — Dynamic Type 확대 시 행이 밀려 커진다.
///
/// 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §5.3
public struct ChalNaListRow: View {

    private static let minHeight: CGFloat = 56

    private enum Kind {
        case navigate(value: String?, action: () -> Void)
        case toggle(isOn: Bool, onChange: (Bool) -> Void)
        case slider(value: Double, range: ClosedRange<Double>, step: Double,
                    trailingText: String?, onChange: (Double) -> Void)
        case check(isChecked: Bool, action: () -> Void)
    }

    private let titleText: Text
    /// LocalizedStringKey 변형과 verbatim 변형이 같은 저장소를 쓰도록 `Text` 로 보관한다.
    private let subtitleText: Text?
    private let enabled: Bool
    private let kind: Kind

    private init(titleText: Text, subtitleText: Text?, enabled: Bool, kind: Kind) {
        self.titleText = titleText
        self.subtitleText = subtitleText
        self.enabled = enabled
        self.kind = kind
    }

    // MARK: - Factories

    public static func navigate(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        value: String? = nil,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> ChalNaListRow {
        .init(titleText: Text(title),
              subtitleText: subtitle.map { Text($0) },
              enabled: enabled,
              kind: .navigate(value: value, action: action))
    }

    public static func toggle(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        isOn: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> ChalNaListRow {
        .init(titleText: Text(title),
              subtitleText: subtitle.map { Text($0) },
              enabled: true,
              kind: .toggle(isOn: isOn, onChange: onChange))
    }

    // MARK: - verbatim 변형
    //
    // `LabelKind.title`/`.subtitle` 처럼 `String(localized:)` 로 **이미 해석된 String** 을 받는 경우용.
    // Task 15 의 라벨 토글 행이 유일한 사용처다.
    // 이를 LocalizedStringKey 로 넘기면 번역 테이블에서 다시 찾는 이중 조회가 되어
    // 조용히 잘못된 동작이 된다.

    public static func toggleVerbatim(
        title: String,
        subtitle: String? = nil,
        isOn: Bool,
        onChange: @escaping (Bool) -> Void
    ) -> ChalNaListRow {
        .init(titleText: Text(verbatim: title),
              subtitleText: subtitle.map { Text(verbatim: $0) },
              enabled: true,
              kind: .toggle(isOn: isOn, onChange: onChange))
    }

    public static func slider(
        title: LocalizedStringKey,
        value: Double,
        range: ClosedRange<Double> = 0...1,
        step: Double = 0.05,
        enabled: Bool = true,
        trailingText: String? = nil,
        onChange: @escaping (Double) -> Void
    ) -> ChalNaListRow {
        .init(titleText: Text(title), subtitleText: nil, enabled: enabled,
              kind: .slider(value: value, range: range, step: step,
                            trailingText: trailingText, onChange: onChange))
    }

    /// 언어 선택처럼 목록에서 하나를 고르는 행. 제목은 이미 해석된 문자열이라 verbatim.
    public static func check(
        verbatimTitle: String,
        isChecked: Bool,
        action: @escaping () -> Void
    ) -> ChalNaListRow {
        .init(titleText: Text(verbatim: verbatimTitle), subtitleText: nil, enabled: true,
              kind: .check(isChecked: isChecked, action: action))
    }

    // MARK: - Body

    public var body: some View {
        switch kind {
        case .navigate(_, let action):
            Button(action: action) { rowContent.contentShape(Rectangle()) }
                .buttonStyle(ListRowPressStyle())
                .disabled(!enabled)
        case .check(_, let action):
            Button(action: action) { rowContent.contentShape(Rectangle()) }
                .buttonStyle(ListRowPressStyle())
        case .toggle, .slider:
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                titleText
                    .font(ChalNaTypography.body)
                    .foregroundColor(enabled ? ChalNaColor.textPrimary : ChalNaColor.textTertiary)
                    .multilineTextAlignment(.leading)

                if let subtitleText {
                    subtitleText
                        .font(ChalNaTypography.label)
                        .foregroundColor(enabled ? ChalNaColor.textSecondary : ChalNaColor.textTertiary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Self.minHeight)
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch kind {
        case .navigate(let value, _):
            HStack(spacing: 6) {
                if let value {
                    Text(verbatim: value)
                        .font(ChalNaTypography.label)
                        .foregroundColor(enabled ? ChalNaColor.textSecondary : ChalNaColor.textTertiary)
                        .lineLimit(1)
                }
                ChalNaIcon(.chevronRight, size: 14, weight: .semibold)
                    .foregroundColor(enabled ? ChalNaColor.textSecondary : ChalNaColor.textTertiary)
            }

        case .toggle(let isOn, let onChange):
            Toggle("", isOn: Binding(get: { isOn }, set: onChange))
                .labelsHidden()
                .tint(ChalNaColor.accentFill)

        case .slider(let value, let range, let step, let trailingText, let onChange):
            HStack(spacing: 10) {
                ChalNaSlider(
                    value: Binding(get: { value }, set: onChange),
                    range: range,
                    step: step
                )
                .frame(minWidth: 120)
                if let trailingText {
                    Text(verbatim: trailingText)
                        .font(ChalNaTypography.mono())
                        .foregroundColor(enabled ? ChalNaColor.textSecondary : ChalNaColor.textTertiary)
                        .frame(minWidth: 44, alignment: .trailing)
                }
            }
            .disabled(!enabled)

        case .check(let isChecked, _):
            ChalNaIcon(.check, size: 16, weight: .semibold)
                .foregroundColor(ChalNaColor.accent)
                .opacity(isChecked ? 1 : 0)

        }
    }
}

private struct ListRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? ChalNaColor.surfaceRaised : Color.clear)
            .animation(ChalNaMotion.fast, value: configuration.isPressed)
    }
}

/// 리스트 행 사이 구분선. 좌측 16pt 인셋으로 텍스트 시작선과 맞춘다.
public struct ChalNaListDivider: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(ChalNaColor.border)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}
