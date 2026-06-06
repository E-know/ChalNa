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
            ChalNaNavigationBar(titleKey: "설정") {
                ChalNaHeaderBackButton { router.pop() }
            } trailing: {
                EmptyView()
            }
            .frame(maxWidth: .infinity)
            .background(
                Color.white
                    .ignoresSafeArea(edges: .top)
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(ChalNaColor.Gray.g200)
                    .frame(height: 1)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
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
                }
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(ChalNaColor.Gray.g100, lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .onAppear { store.send(.onAppear) }
    }

    @ViewBuilder
    private func menuRow(title: LocalizedStringKey, subtitle: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ChalNaColor.Gray.g900)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(ChalNaColor.Gray.g500)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ChalNaColor.Gray.g400)
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
