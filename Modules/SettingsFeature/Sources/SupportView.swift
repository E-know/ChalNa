import SwiftUI
import ComposableArchitecture
import AppCore
import DesignSystem

/// 문의·신고 화면. 분류 칩 + 멀티라인 입력 + 전송 버튼.
public struct SupportView: View {
    @Environment(AppRouter.self) private var router
    @Bindable var store: StoreOf<SupportFeature>

    private let placeholder = String(localized: "불편한 점이나 제안을 자유롭게 적어주세요.")

    public init(store: StoreOf<SupportFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .chalNaHeaderBar(scrollProgress: 1)
                .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    categoryPicker
                    editor
                    Text("모든 제보는 익명으로 전송돼요.")
                        .font(ChalNaTypography.krBody(ChalNaTypography.Size.caption))
                        .foregroundColor(ChalNaColor.taupe)
                    sendButton
                }
                .padding(.horizontal, 24)
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
        ) { info in
            Button("확인", role: .cancel) {
                // 알림 상태를 먼저 비운 뒤(재표시 방지) pop. 성공 시에만 화면을 닫는다(실패면 머물러 재시도).
                store.send(.alertDismissed)
                if info.isSuccess { router.pop() }
            }
        } message: { info in
            Text(info.message)
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("문의·신고")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .semibold))
                .foregroundColor(ChalNaColor.ink)
            HStack {
                Button { router.pop() } label: {
                    ChalNaIcon(.chevronLeft, size: 22)
                        .foregroundColor(ChalNaColor.ink)
                }
                .buttonStyle(.chalNaHeaderAction)
                .accessibilityLabel("뒤로")
                Spacer()
            }
        }
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

    /// 아이콘 없는 텍스트 전용 칩. 내용과 stroke 사이 여백을 넉넉히.
    private func categoryChip(_ category: FeedbackCategory) -> some View {
        let isSelected = store.category == category
        return Text(category.koreanName)
            .font(ChalNaTypography.krBody(ChalNaTypography.Size.small, weight: .semibold))
            .foregroundColor(isSelected ? ChalNaColor.white : ChalNaColor.taupe)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? ChalNaColor.ink : ChalNaColor.white)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : ChalNaColor.Gray.g300, lineWidth: 1)
            )
    }

    // MARK: - Editor

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if store.text.isEmpty {
                Text(placeholder)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                    .foregroundColor(ChalNaColor.taupe)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $store.text.sending(\.textChanged))
                .scrollContentBackground(.hidden)
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                .foregroundColor(ChalNaColor.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 180)
        }
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.button, style: .continuous)
                .fill(ChalNaColor.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.button, style: .continuous)
                .strokeBorder(ChalNaColor.Gray.g200, lineWidth: 1)
        )
    }

    // MARK: - Send

    private var sendButton: some View {
        Button {
            store.send(.sendTapped)
        } label: {
            if store.isSending {
                ProgressView().tint(ChalNaColor.white)
            } else {
                Text("전송")
            }
        }
        .buttonStyle(.chalNa(.filled, size: .lg, fillWidth: true))
        .disabled(isSendDisabled)
    }

    private var isSendDisabled: Bool {
        store.isSending || store.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    SupportView(store: Store(initialState: SupportFeature.State()) { SupportFeature() })
        .environment(AppRouter())
}
