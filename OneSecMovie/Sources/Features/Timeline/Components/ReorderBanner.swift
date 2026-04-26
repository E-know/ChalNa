import SwiftUI

/// Reordering 상태에서 프리뷰 중앙에 뜨는 안내 배너.
struct ReorderBanner: View {
    var body: some View {
        HStack(spacing: MomentsSpacing.sm) {
            MomentsIcon(.move, size: 20)
                .foregroundColor(MomentsColor.coral)
            VStack(alignment: .leading, spacing: 2) {
                Text("순서를 바꾸려면")
                    .font(MomentsTypography.krSemibold(13))
                    .foregroundColor(MomentsColor.ink)
                Text("길게 눌러 원하는 위치로 끌어주세요")
                    .font(MomentsTypography.krBody(12))
                    .foregroundColor(MomentsColor.taupe)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, MomentsSpacing.md)
        .padding(.vertical, MomentsSpacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                .fill(MomentsColor.cream.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MomentsRadius.button, style: .continuous)
                .strokeBorder(MomentsColor.coral, style: .init(lineWidth: 1, dash: [5, 3]))
        )
        .shadow(color: MomentsColor.ink.opacity(0.25), radius: 14, y: 8)
    }
}
