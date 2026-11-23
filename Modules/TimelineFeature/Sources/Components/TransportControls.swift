import SwiftUI
import ComposableArchitecture
import DesignSystem

struct TransportControls: View {
    let store: StoreOf<TimelineFeature>

    var body: some View {
        VStack(spacing: 2) {
            ChalNaProgressBar(progress: store.playheadSeconds / max(store.totalDuration, 0.001), height: 2)
            HStack(spacing: 0) {
                Text(verbatim: store.playheadLabel)
                    .accessibilityIdentifier("timeline.playhead")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { store.send(.previousTapped) } label: {
                    ChalNaIcon(.chevronLeft, size: 14).frame(width: 44, height: 44)
                }
                .disabled(store.currentIndex == 0)
                .accessibilityLabel("이전 클립")
                Button { store.send(.togglePlay) } label: {
                    ChalNaIcon(store.isPlaying ? .pause : .play, size: 13)
                        .foregroundStyle(ChalNaColor.onAccent)
                        .frame(width: 34, height: 34)
                        .background(ChalNaColor.textPrimary, in: Circle())
                        .frame(width: 48, height: 44)
                }
                .accessibilityLabel(store.isPlaying ? LocalizedStringKey("일시정지") : "재생")
                .disabled(store.clips.isEmpty)
                Button { store.send(.nextTapped) } label: {
                    ChalNaIcon(.chevronRight, size: 14).frame(width: 44, height: 44)
                }
                .disabled(store.currentIndex + 1 >= store.clips.count)
                .accessibilityLabel("다음 클립")
                Text(verbatim: store.totalClockLabel)
                    .foregroundStyle(ChalNaColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(ChalNaTypography.label)
            .monospacedDigit()
            .buttonStyle(.plain)
        }
    }
}
