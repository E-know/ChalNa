import SwiftUI

/// Custom navigation header used when the system navigation bar is hidden.
/// Keeps left/right action slots symmetric so title placement does not depend on hidden spacer views.
public struct ChalNaNavigationBar<Leading: View, Trailing: View>: View {
    private let titleText: Text
    private let subtitleText: Text?
    private let subtitleColor: Color
    private let leading: Leading
    private let trailing: Trailing

    public init(
        titleKey: LocalizedStringKey,
        subtitleKey: LocalizedStringKey? = nil,
        subtitleColor: Color = ChalNaColor.Gray.g500,
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
        subtitleColor: Color = ChalNaColor.Gray.g500,
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
                    .frame(maxHeight: 44, alignment: .leading)

                Spacer()

                trailing
                    .frame(maxHeight: 44, alignment: .trailing)
            }

            VStack(spacing: 2) {
                titleText
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ChalNaColor.Gray.g900)
                    .lineLimit(1)

                if let subtitleText {
                    subtitleText
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }
            }
            .frame(maxHeight: 44)
        }
        .frame(maxWidth: .infinity)
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
            Image(systemName: "chevron.left")
                .resizable()
                .scaledToFit()
                .frame(height: 22)
                .foregroundStyle(ChalNaColor.Gray.g900)
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
            Image(systemName: "xmark")
                .resizable()
                .scaledToFit()
                .frame(height: 22)
                .foregroundStyle(ChalNaColor.Gray.g900)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ChalNaColor.Purple.p600)
        }
        .buttonStyle(.chalNaHeaderAction)
    }
}
