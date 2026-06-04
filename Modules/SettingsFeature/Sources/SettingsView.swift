import SwiftUI
import ComposableArchitecture
import AppCore
import DesignSystem

/// 설정 최상위 메뉴. 현재 '라벨' 항목 1개 — 향후 다른 메뉴 행을 카드에 추가.
public struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    let store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .chalNaHeaderBar(scrollProgress: 1)
                .zIndex(1)

            ScrollView {
                VStack(spacing: 0) {
                    menuRow(title: "라벨", subtitle: "영상에 표시되는 시각·날짜 라벨") {
                        store.send(.labelMenuTapped)
                        router.push(.labelSettings)
                    }
                    Divider().overlay(ChalNaColor.Gray.g100)
                    menuRow(title: "언어", subtitle: "앱 표시 언어를 선택하세요") {
                        router.push(.language)
                    }
                    Divider().overlay(ChalNaColor.Gray.g100)
                    menuRow(title: "문의·신고", subtitle: "불편한 점이나 제안을 보내주세요") {
                        store.send(.supportMenuTapped)
                        router.push(.support)
                    }
                    // 향후 다른 설정 메뉴 행은 여기에 Divider + menuRow 로 추가
                }
                .background(
                    RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                        .strokeBorder(ChalNaColor.Gray.g100, lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .chalNaScreen()
        .onAppear { store.send(.onAppear) }
    }

    private var header: some View {
        ChalNaNavigationHeader(titleKey: "설정") {
            ChalNaHeaderBackButton { router.pop() }
        } trailing: {
            EmptyView()
        }
    }

    @ViewBuilder
    private func menuRow(title: LocalizedStringKey, subtitle: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ChalNaTypography.krBody(ChalNaTypography.Size.body, weight: .semibold))
                        .foregroundColor(ChalNaColor.ink)
                    Text(subtitle)
                        .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
                        .foregroundColor(ChalNaColor.taupe)
                }
                Spacer()
                ChalNaIcon(.chevronRight, size: 16)
                    .foregroundColor(ChalNaColor.Gray.g400)
            }
            .padding(16)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(store: Store(initialState: SettingsFeature.State()) { SettingsFeature() })
        .environment(AppRouter())
}
