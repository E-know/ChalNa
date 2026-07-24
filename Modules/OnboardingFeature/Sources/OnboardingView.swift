import ComposableArchitecture
import DesignSystem
import SwiftUI

/// 온보딩 루트. stage 에 따라 페이지(TabView) ↔ 페이월을 전환한다.
/// 하드 페이월: 닫기 수단 없음. 게이트 해제는 delegate(.completed) → AppFeature.
public struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(store: StoreOf<OnboardingFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.stage {
            case .pages:   pages
            case .paywall: PaywallView(store: store)
            }
        }
        .chalNaScreen()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.stage)
        .onAppear { store.send(.onAppear) }
    }

    private var pages: some View {
        VStack(spacing: 0) {
            TabView(selection: $store.pageIndex.sending(\.pageChanged)) {
                Value1PageView()
                    .tag(OnboardingFeature.Page.value1.rawValue)
                InterestPageView(
                    selected: store.selectedInterest,
                    onTap: { store.send(.interestTapped($0)) }
                )
                .tag(OnboardingFeature.Page.interest.rawValue)
                SortingPageView()
                    .tag(OnboardingFeature.Page.sorting.rawValue)
                LabelsPageView()
                    .tag(OnboardingFeature.Page.labels.rawValue)
                SubtitlePageView()
                    .tag(OnboardingFeature.Page.subtitle.rawValue)
                PermissionPageView()
                    .tag(OnboardingFeature.Page.permission.rawValue)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.bottom, 24)

            Button(store.pageIndex == OnboardingFeature.Page.permission.rawValue ? "계속" : "다음") {
                store.send(.nextTapped)
            }
            .buttonStyle(.chalNa(.filled, size: .xl, fillWidth: true))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<OnboardingFeature.Page.count, id: \.self) { index in
                Circle()
                    .fill(index == store.pageIndex ? ChalNaColor.Purple.p600 : ChalNaColor.Gray.g200)
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.pageIndex)
    }
}

#Preview("온보딩 전체") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(mode: .full)) { OnboardingFeature() }
    )
}
