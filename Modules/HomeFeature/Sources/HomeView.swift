import SwiftUI
import ComposableArchitecture
import AppCore
import DesignSystem

public struct HomeView: View {
    @Environment(AppLanguageStore.self) private var languageStore
    private var films: [ArchivedFilm] { store.films }
    let store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature> = Store(initialState: HomeFeature.State()) { HomeFeature() }) {
        self.store = store
    }

    public var body: some View {
        GeometryReader { proxy in
            let split = ChalNaLayout.isSplit(proxy.size) && !films.isEmpty
            VStack(alignment: .leading, spacing: 16) {
                header
                if store.readFailed && !films.isEmpty { retryLoad }
                if let latest = films.first {
                    if split {
                        HStack(alignment: .top, spacing: 32) {
                            coverButton(latest)
                                .frame(width: max(1, (proxy.size.width - 80) * 0.51))
                                .frame(maxHeight: .infinity)
                            VStack(spacing: 12) {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 32) {
                                        featuredInfo(latest)
                                        archive
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                primaryAction
                            }
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                coverButton(latest)
                                    .frame(height: max(0, min((proxy.size.width - 48) * 0.78, proxy.size.height * 0.40)))
                                featuredInfo(latest)
                                archive
                            }
                            .padding(.bottom, 8)
                        }
                    }
                } else if store.readFailed {
                    retryLoad.frame(maxHeight: .infinity, alignment: .topLeading)
                } else if store.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    emptyLibrary
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !split {
                    primaryAction.padding(.horizontal, 24).padding(.vertical, 8)
                        .background(ChalNaColor.bg)
                }
            }
        }
        .chalNaScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("설정", systemImage: "gearshape") { store.send(.settingsButtonTapped) }
                    .accessibilityIdentifier("home.settings")
            }
        }
        .onAppear { store.send(.onAppear) }
        .task { await store.send(.task).finish() }
        .onDisappear { store.send(.disappeared) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("필름 보관함")
                .font(ChalNaTypography.display)
                .foregroundStyle(ChalNaColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if !films.isEmpty {
                Text("\(films.count)편")
                    .font(ChalNaTypography.label)
                    .foregroundStyle(ChalNaColor.textSecondary)
            }
        }
    }

    private var retryLoad: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("필름 보관함을 불러오지 못했어요.").font(ChalNaTypography.headline)
            Button("다시 시도") { store.send(.retryTapped) }
                .buttonStyle(.chalNa(.secondary, size: .md))
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyLibrary: some View {
        ScrollView {
            VStack(spacing: 16) {
                ChalNaEmptyState(icon: .film, title: "아직 완성한 필름이 없어요",
                                 message: "Live Photo와 동영상으로\n첫 필름을 만들어 보세요.")
                if !languageStore.isKoreanUI {
                    Text("'찰나'는 아주 짧은 순간이라는 뜻이에요.")
                        .font(ChalNaTypography.label)
                        .foregroundStyle(ChalNaColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        }
    }

    private func coverButton(_ film: ArchivedFilm) -> some View {
        Button {
            store.send(.filmTapped(filmID: film.id))
        } label: {
            cover(film)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(film.title), \(film.metaLabel)"))
        .accessibilityIdentifier("home.latestFilm")
    }

    private func featuredInfo(_ film: ArchivedFilm) -> some View {
        Button {
            store.send(.filmTapped(filmID: film.id))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("최근 완성한 필름")
                        .font(ChalNaTypography.label).foregroundStyle(ChalNaColor.accent)
                    Text(verbatim: film.title)
                        .font(ChalNaTypography.screenTitle).foregroundStyle(ChalNaColor.textPrimary)
                    Text(verbatim: film.metaLabel)
                        .font(ChalNaTypography.caption).foregroundStyle(ChalNaColor.textSecondary)
                }
                Spacer(minLength: 0)
                ChalNaIcon(.chevronRight, size: 16)
                    .foregroundStyle(ChalNaColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(ChalNaColor.surface, in: Circle())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(film.title), \(film.metaLabel)"))
    }

    @ViewBuilder
    private var archive: some View {
        if films.count > 1 {
            LazyVStack(alignment: .leading, spacing: 12) {
                Divider()
                Text("이전 필름")
                    .font(ChalNaTypography.headline)
                    .foregroundStyle(ChalNaColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                ForEach(films.dropFirst(), id: \.id) { film in
                    Button {
                        store.send(.filmTapped(filmID: film.id))
                    } label: {
                        HStack(spacing: 14) {
                            cover(film).frame(width: 76, height: 76)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: film.title).font(ChalNaTypography.headline)
                                    .foregroundStyle(ChalNaColor.textPrimary)
                                Text(verbatim: film.metaLabel).font(ChalNaTypography.caption)
                                    .foregroundStyle(ChalNaColor.textSecondary)
                            }
                            Spacer(minLength: 0)
                            ChalNaIcon(.chevronRight, size: 13).foregroundStyle(ChalNaColor.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: "\(film.title), \(film.metaLabel)"))
                }
            }
        }
    }

    private func cover(_ film: ArchivedFilm) -> some View {
        Rectangle().fill(ChalNaColor.surface)
            .overlay {
                if let data = film.thumbnailData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ChalNaIcon(.film, size: 24).foregroundStyle(ChalNaColor.textSecondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.xxs))
    }

    private var primaryAction: some View {
        Button {
            store.send(.newVlogButtonTapped)
        } label: {
            HStack {
                ChalNaIcon(.plus, size: 16)
                Spacer()
                Text(films.isEmpty ? "첫 필름 만들기" : "새 필름 만들기")
                Spacer()
                Color.clear.frame(width: 16, height: 1)
            }
        }
        .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
        .accessibilityIdentifier("home.newFilm")
    }
}
