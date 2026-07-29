import SwiftUI
import ComposableArchitecture
import DesignSystem

/// 문의·신고 화면. 분류 칩 + 멀티라인 입력 + 전송 버튼.
public struct SupportView: View {
    @Bindable var store: StoreOf<SupportFeature>

    private let placeholder = String(localized: "불편한 점이나 제안을 자유롭게 적어주세요.")

    public init(store: StoreOf<SupportFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    categoryPicker
                    editor
                    Text("모든 제보는 익명으로 전송돼요.")
                        .font(ChalNaTypography.caption)
                        .foregroundColor(ChalNaColor.textSecondary)
                    sendButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 64)
            }
        }
        .chalNaScreen()
        .alert(
            "알림",
            isPresented: Binding(
                get: { store.alert != nil },
                set: { if !$0 { store.send(.alertDismissed) } }
            ),
            presenting: store.alert
        ) { _ in
            Button("확인", role: .cancel) {
                // 성공 시 화면 닫기 판단은 reducer(alertDismissed)가 한다.
                store.send(.alertDismissed)
            }
        } message: { info in
            Text(info.message)
        }
        .sheet(
            isPresented: Binding(
                get: { store.isRedeemPresented },
                set: { store.send(.redeemPresentedChanged($0)) }
            )
        ) {
            redeemCodeSheet
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
                .presentationBackground(ChalNaColor.surfaceRaised)
        }
    }

    // MARK: - Header

    private var header: some View {
        ChalNaNavBar(
            title: "문의·신고",
            leading: .back { store.send(.backTapped) },
            showsDivider: true
        )
    }

    // MARK: - Category

    private var categoryPicker: some View {
        HStack(spacing: 8) {
            ForEach(FeedbackCategory.allCases, id: \.self) { category in
                Button {
                    store.send(.categorySelected(category))
                } label: {
                    categoryChip(category)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    /// 아이콘 없는 텍스트 전용 선택 칩.
    private func categoryChip(_ category: FeedbackCategory) -> some View {
        let isSelected = store.category == category
        return Text(verbatim: category.koreanName)
            .font(ChalNaTypography.label)
            .foregroundColor(isSelected ? ChalNaColor.accent : ChalNaColor.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? ChalNaColor.accentFill.opacity(0.22) : ChalNaColor.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? ChalNaColor.accent : ChalNaColor.border, lineWidth: 1)
            )
            .contentShape(Capsule())
    }

    // MARK: - Editor

    private var editor: some View {
        ChalNaTextArea(placeholder: placeholder, minHeight: 180,
                       text: $store.text.sending(\.textChanged))
    }

    // MARK: - Send

    private var sendButton: some View {
        Button {
            store.send(.sendTapped)
        } label: {
            if store.isSending {
                ProgressView().tint(ChalNaColor.onAccent)
            } else {
                Text("전송")
            }
        }
        .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
        .disabled(isSendDisabled)
    }

    private var isSendDisabled: Bool {
        store.isSending || store.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var redeemCodeSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("리딤 코드")
                .font(ChalNaTypography.title)
                .foregroundColor(ChalNaColor.textPrimary)

            Text("코드를 입력하면 2026년까지 영상 생성 제한이 해제돼요.")
                .font(ChalNaTypography.label)
                .foregroundColor(ChalNaColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ChalNaTextField(
                placeholder: "Redeem Code",
                errorText: store.redeemError,
                text: $store.redeemCode.sending(\.redeemCodeChanged)
            )

            Button {
                store.send(.redeemSubmitted)
            } label: {
                Text("적용")
            }
            .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
            .disabled(store.redeemCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ChalNaColor.surfaceRaised.ignoresSafeArea())
    }
}

#Preview {
    SupportView(store: Store(initialState: SupportFeature.State()) { SupportFeature() })
}
