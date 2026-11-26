import SwiftUI
import ComposableArchitecture
import DesignSystem
import Models

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preferredCompactColumn = NavigationSplitViewColumn.sidebar
    @Bindable var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) { self.store = store }

    public var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredCompactColumn) {
            List(selection: $store.selectedSection.sending(\.sectionSelected)) {
                menuLink(.language, title: "언어", subtitle: "앱 표시 언어를 선택하세요")
                    .accessibilityIdentifier("settings.language")
                menuLink(.support, title: "문의·신고", subtitle: "불편한 점이나 제안을 보내주세요")
                    .accessibilityIdentifier("settings.support")
                outputResolutionPicker
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .chalNaScreen()
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기", systemImage: "xmark") { dismiss() }
                        .accessibilityIdentifier("settings.close")
                }
            }
        } detail: {
            switch store.selectedSection {
            case .language:
                LanguageView(store: store.scope(state: \.language, action: \.language))
            case .support:
                SupportView(store: store.scope(state: \.support, action: \.support))
            case nil:
                Text("설정 항목을 선택하세요")
                    .font(ChalNaTypography.body)
                    .foregroundStyle(ChalNaColor.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .chalNaScreen()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: store.selectedSection) { _, section in
            preferredCompactColumn = section == nil ? .sidebar : .detail
        }
        .onAppear { store.send(.onAppear) }
    }

    private var outputResolutionPicker: some View {
        Picker(selection: $store.outputResolution.sending(\.outputResolutionSelected)) {
            ForEach(FilmOutputResolution.allCases, id: \.self) { resolution in
                Text(verbatim: resolution.title).tag(resolution)
            }
        } label: {
            Text("영상 해상도")
                .font(ChalNaTypography.body)
                .foregroundStyle(ChalNaColor.textPrimary)
        }
        .pickerStyle(.menu)
        .tint(ChalNaColor.accent)
        .frame(minHeight: 56)
        .listRowBackground(ChalNaColor.bg)
        .listRowSeparatorTint(ChalNaColor.border)
        .accessibilityHint(Text("내보낼 영상의 해상도를 선택하세요"))
        .accessibilityIdentifier("settings.filmOutputResolution")
    }

    private func menuLink(_ section: SettingsFeature.Section, title: LocalizedStringKey,
                          subtitle: LocalizedStringKey) -> some View {
        NavigationLink(value: section) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ChalNaTypography.body)
                    .foregroundStyle(ChalNaColor.textPrimary)
                Text(subtitle)
                    .font(ChalNaTypography.label)
                    .foregroundStyle(ChalNaColor.textSecondary)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 56, alignment: .leading)
        }
        .tag(section)
        .listRowBackground(store.selectedSection == section ? ChalNaColor.selection : ChalNaColor.bg)
        .listRowSeparatorTint(ChalNaColor.border)
    }
}
