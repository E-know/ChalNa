import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

public struct LabelSettingsView: View {
    @Environment(AppRouter.self) private var router
    let store: StoreOf<LabelSettingsFeature>

    public init(store: StoreOf<LabelSettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .chalNaHeaderBar(scrollProgress: 1)
                .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 0) {
                        labelRows(
                            kind: .time,
                            isOn: store.timeEnabled,
                            position: store.timePosition,
                            opacity: store.timeOpacity,
                            onToggle: { store.send(.timeToggled($0)) },
                            onPositionTap: {
                                store.send(.timePositionRowTapped)
                                router.push(.labelPosition(.time))
                            },
                            onOpacityChange: { store.send(.timeOpacityChanged($0)) }
                        )
                        Divider().overlay(ChalNaColor.Gray.g100)
                        labelRows(
                            kind: .date,
                            isOn: store.dateEnabled,
                            position: store.datePosition,
                            opacity: store.dateOpacity,
                            onToggle: { store.send(.dateToggled($0)) },
                            onPositionTap: {
                                store.send(.datePositionRowTapped)
                                router.push(.labelPosition(.date))
                            },
                            onOpacityChange: { store.send(.dateOpacityChanged($0)) }
                        )
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
                }
                .padding(.top, 16)
                .padding(.bottom, 64)
            }
        }
        .chalNaScreen()
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("라벨")
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

    // MARK: - Rows

    @ViewBuilder
    private func labelRows(
        kind: LabelKind,
        isOn: Bool,
        position: LabelPosition,
        opacity: Double,
        onToggle: @escaping (Bool) -> Void,
        onPositionTap: @escaping () -> Void,
        onOpacityChange: @escaping (Double) -> Void
    ) -> some View {
        // 토글 행
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body, weight: .semibold))
                    .foregroundColor(ChalNaColor.ink)
                Text(kind.subtitle)
                    .font(ChalNaTypography.monoFallback(ChalNaTypography.Size.caption))
                    .foregroundColor(ChalNaColor.taupe)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: onToggle))
                .labelsHidden()
                .tint(ChalNaColor.coral)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)

        // 위치 행 (OFF 면 비활성)
        Button(action: onPositionTap) {
            HStack(spacing: 12) {
                Text("위치")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                    .foregroundColor(isOn ? ChalNaColor.ink : ChalNaColor.Gray.g300)
                Spacer()
                Text(position.koreanName)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
                    .foregroundColor(isOn ? ChalNaColor.taupe : ChalNaColor.Gray.g300)
                ChalNaIcon(.chevronRight, size: 16)
                    .foregroundColor(isOn ? ChalNaColor.Gray.g400 : ChalNaColor.Gray.g300)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isOn)

        // 투명도 행 (OFF 면 비활성)
        HStack(spacing: 12) {
            Text("투명도")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                .foregroundColor(isOn ? ChalNaColor.ink : ChalNaColor.Gray.g300)
            Slider(value: Binding(get: { opacity }, set: onOpacityChange), in: 0...1, step: 0.05)
                .tint(ChalNaColor.coral)
            Text("\(Int((opacity * 100).rounded()))%")
                .font(ChalNaTypography.monoFallback(ChalNaTypography.Size.caption))
                .foregroundColor(isOn ? ChalNaColor.taupe : ChalNaColor.Gray.g300)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .disabled(!isOn)
    }
}

#Preview {
    LabelSettingsView(store: Store(initialState: LabelSettingsFeature.State()) { LabelSettingsFeature() })
        .environment(AppRouter())
}
