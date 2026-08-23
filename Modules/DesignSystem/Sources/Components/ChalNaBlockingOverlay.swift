import SwiftUI

/// 작업 중 하단 화면 조작을 막는 전체 오버레이.
/// MediaPicker 의 Live Photo·영상 추출 진행 표시에 쓴다.
public struct ChalNaBlockingOverlay: View {
    private let title: LocalizedStringKey
    private let detail: LocalizedStringKey?
    /// "05 / 12" 같은 숫자 진행 표시. 숫자 전용이라 mono 를 쓴다.
    private let progressText: String?
    private let a11yLabel: LocalizedStringKey

    public init(
        title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        progressText: String? = nil,
        accessibilityLabel: LocalizedStringKey
    ) {
        self.title = title
        self.detail = detail
        self.progressText = progressText
        self.a11yLabel = accessibilityLabel
    }

    public var body: some View {
        ZStack {
            ChalNaColor.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }   // 하단 화면 탭 차단

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(ChalNaColor.accent)

                VStack(spacing: 6) {
                    Text(title)
                        .font(ChalNaTypography.headline)
                        .foregroundColor(ChalNaColor.textPrimary)

                    if let progressText {
                        Text(verbatim: progressText)
                            .font(ChalNaTypography.title)
                            .fontWeight(.bold)
                            .foregroundColor(ChalNaColor.accent)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }

                    if let detail {
                        Text(detail)
                            .font(ChalNaTypography.caption)
                            .foregroundColor(ChalNaColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(minWidth: 220)
            .background(
                RoundedRectangle(cornerRadius: ChalNaRadius.lg, style: .continuous)
                    .fill(ChalNaColor.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChalNaRadius.lg, style: .continuous)
                    .strokeBorder(ChalNaColor.border, lineWidth: 1)
            )
            .chalNaShadow(ChalNaShadow.floating)
            .padding(.horizontal, 48)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(a11yLabel)
    }
}

#Preview {
    Color.gray
        .overlay {
            ChalNaBlockingOverlay(
                title: "사진을 불러오는 중",
                detail: "Live Photo와 영상을 정성껏 추출하고 있어요",
                progressText: "05 / 12",
                accessibilityLabel: "사진을 불러오는 중이에요"
            )
        }
        .ignoresSafeArea()
}
