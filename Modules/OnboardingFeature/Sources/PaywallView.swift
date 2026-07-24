import ComposableArchitecture
import DesignSystem
import SwiftUI

/// 하드 페이월 — Blinkist Honest Paywall 패턴.
/// Apple Schedule 2 §3.8(b): 구독명·기간·가격을 이 화면에 명시. 복원/약관/개인정보 링크 필수.
public struct PaywallView: View {
    @Bindable var store: StoreOf<OnboardingFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stepsShown = 0
    @State private var ctaBounced = false

    public init(store: StoreOf<OnboardingFeature>) {
        self.store = store
    }

    /// ⚠️ 출시 전 실제 URL 확정 필요 (App Store Connect 메타데이터에도 동일 등록).
    private enum Legal {
        static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
        static let privacy = URL(string: "https://chalna.app/privacy")!
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            header
            timeline
                .padding(.horizontal, 24)
                .padding(.top, 28)
            priceCard
                .padding(.horizontal, 24)
                .padding(.top, 24)
            Spacer(minLength: 16)
            ctaBlock
            legalLinks
                .padding(.top, 20)
                .padding(.bottom, 12)
        }
        .overlay(alignment: .bottom) { toast }
        .onAppear(perform: runEntrance)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            ChalNaIcon(.film, size: 44)
                .foregroundColor(ChalNaColor.Purple.p600)
            Text(verbatim: "ChalNa Pro")
                .font(ChalNaTypography.displayKR(ChalNaTypography.Size.displayS, weight: .bold))
                .foregroundColor(ChalNaColor.Gray.g900)
            Text(store.paywallSubtitle)
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2))
                .foregroundColor(ChalNaColor.Gray.g500)
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineStep(
                index: 0, symbol: "lock.open", filled: true,
                title: "오늘 — 모든 기능 잠금 해제",
                description: "바로 첫 필름을 만들어보세요"
            )
            connector
            timelineStep(
                index: 1, symbol: "bell", filled: false,
                title: "2일차 — 종료 전 알림",
                description: "체험이 끝나기 전에 미리 알려드려요"
            )
            connector
            timelineStep(
                index: 2, symbol: "star", filled: false,
                title: "3일차 — 구독 시작",
                description: "\(store.product?.displayPrice ?? "₩1,500")/주 · 시작 전 언제든 취소"
            )
        }
    }

    private func timelineStep(index: Int, symbol: String, filled: Bool, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(filled ? ChalNaColor.Purple.p600 : ChalNaColor.Purple.p100.opacity(0.55))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: symbol)
                        .font(ChalNaTypography.krBody(15, weight: .semibold))
                        .foregroundColor(filled ? .white : ChalNaColor.Purple.p600)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2, weight: .bold))
                    .foregroundColor(ChalNaColor.Gray.g900)
                Text(description)
                    .font(ChalNaTypography.krBody(13))
                    .foregroundColor(ChalNaColor.Gray.g500)
            }
            Spacer(minLength: 0)
        }
        .opacity(stepsShown > index ? 1 : 0)
        .offset(y: stepsShown > index || reduceMotion ? 0 : 10)
    }

    private var connector: some View {
        Rectangle()
            .fill(ChalNaColor.Purple.p100)
            .frame(width: 2, height: 22)
            .padding(.leading, 17)
            .padding(.vertical, 4)
    }

    private var priceCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("주간 구독")
                    .font(ChalNaTypography.krBody(13))
                    .foregroundColor(ChalNaColor.Gray.g500)
                if store.productLoadFailed {
                    Button("가격을 불러오지 못했어요 · 다시 시도") {
                        store.send(.retryLoadTapped)
                    }
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2, weight: .semibold))
                    .foregroundColor(ChalNaColor.Purple.p600)
                } else {
                    Text(store.priceLine)
                        .font(ChalNaTypography.krBody(17, weight: .bold))
                        .foregroundColor(ChalNaColor.Gray.g900)
                }
            }
            Spacer()
            // ChalNaChip 은 leading 글리프를 강제하므로 텍스트 전용 캡슐을 인라인 구성.
            Text("3일 무료")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.tag, weight: .bold))
                .foregroundColor(ChalNaColor.Purple.p600)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule(style: .continuous).fill(ChalNaColor.Purple.p100))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .strokeBorder(ChalNaColor.Purple.p600, lineWidth: 1.5)
        )
    }

    private var ctaBlock: some View {
        VStack(spacing: 10) {
            Button {
                store.send(.purchaseTapped)
            } label: {
                if store.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("3일 무료로 시작하기")
                }
            }
            .buttonStyle(.chalNa(.filled, size: .xl, fillWidth: true))
            .disabled(store.isPurchasing)
            .scaleEffect(ctaBounced || reduceMotion ? 1.0 : 0.98)
            .padding(.horizontal, 24)

            VStack(spacing: 3) {
                Text("지금은 결제되지 않아요")
                    .font(ChalNaTypography.krBody(13))
                Text("3일 후 \(store.product?.displayPrice ?? "₩1,500")/주 자동 갱신 · 언제든 취소 가능")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.caption))
            }
            .foregroundColor(ChalNaColor.Gray.g500)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 6) {
            Button("구매 복원") { store.send(.restoreTapped) }
                .disabled(store.isRestoring)
            Text(verbatim: "·")
            Link("이용약관", destination: Legal.terms)
            Text(verbatim: "·")
            Link("개인정보처리방침", destination: Legal.privacy)
        }
        .font(ChalNaTypography.krBody(ChalNaTypography.Size.caption))
        .foregroundColor(ChalNaColor.Gray.g500)
    }

    @ViewBuilder
    private var toast: some View {
        if let message = store.toast {
            Text(message)
                .font(ChalNaTypography.krBody(13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(ChalNaColor.Gray.g900.opacity(0.9)))
                .padding(.bottom, 120)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .task {
                    try? await Task.sleep(for: .seconds(2.2))
                    store.send(.toastDismissed)
                }
        }
    }

    // MARK: - Entrance

    private func runEntrance() {
        guard stepsShown == 0 else { return }
        if reduceMotion {
            stepsShown = 3
            ctaBounced = true
            return
        }
        for i in 1...3 {
            withAnimation(.easeOut(duration: 0.35).delay(Double(i - 1) * 0.12)) { stepsShown = i }
        }
        withAnimation(.spring(duration: 0.4).delay(0.5)) { ctaBounced = true }
    }
}

#Preview("페이월") {
    PaywallView(
        store: Store(initialState: OnboardingFeature.State(mode: .paywallOnly)) { OnboardingFeature() }
    )
    .chalNaScreen()
}
