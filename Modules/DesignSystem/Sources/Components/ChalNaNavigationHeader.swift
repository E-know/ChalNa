import SwiftUI

/// Custom navigation header used when the system navigation bar is hidden.
/// Keeps left/right action slots symmetric so title placement does not depend on hidden spacer views.
public struct ChalNaNavigationHeader<Leading: View, Trailing: View>: View {
    private let titleText: Text
    private let subtitleText: Text?
    private let subtitleColor: Color
    private let leading: Leading
    private let trailing: Trailing

    public init(
        titleKey: LocalizedStringKey,
        subtitleKey: LocalizedStringKey? = nil,
        subtitleColor: Color = ChalNaColor.taupe,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.titleText = Text(titleKey)
        self.subtitleText = subtitleKey.map { Text($0) }
        self.subtitleColor = subtitleColor
        self.leading = leading()
        self.trailing = trailing()
    }

    public init(
        title: String,
        subtitle: String? = nil,
        subtitleColor: Color = ChalNaColor.taupe,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.titleText = Text(verbatim: title)
        self.subtitleText = subtitle.map { Text(verbatim: $0) }
        self.subtitleColor = subtitleColor
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        ZStack {
            HStack(spacing: 0) {
                leading
                    .frame(minWidth: 44, alignment: .leading)
                Spacer(minLength: 0)
                trailing
                    .frame(minWidth: 44, alignment: .trailing)
            }

            VStack(spacing: 2) {
                titleText
                    .font(ChalNaTypography.krSemibold(15))
                    .foregroundColor(ChalNaColor.ink)
                    .lineLimit(1)

                if let subtitleText {
                    subtitleText
                        .tagLabel(color: subtitleColor)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 72)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 44)
    }
}

public struct ChalNaHeaderBackButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ChalNaIcon(.chevronLeft, size: 22)
                .foregroundColor(ChalNaColor.ink)
        }
        .buttonStyle(.chalNaHeaderAction)
        .accessibilityLabel("뒤로")
    }
}

public struct ChalNaHeaderCloseButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ChalNaIcon(.close, size: 20)
                .foregroundColor(ChalNaColor.ink)
        }
        .buttonStyle(.chalNaHeaderAction)
        .accessibilityLabel("취소")
    }
}

public struct ChalNaHeaderTextAction: View {
    private let titleKey: LocalizedStringKey
    private let action: () -> Void

    public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(titleKey)
                .font(ChalNaTypography.krBody(14, weight: .semibold))
                .foregroundColor(ChalNaColor.coral)
        }
        .buttonStyle(.chalNaHeaderAction)
    }
}
