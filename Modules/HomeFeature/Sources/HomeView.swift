import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem
import SwiftData

/// 앱 루트 화면.
///
/// 재방문 사용자에게 가치 있는 것은 **만든 필름**이므로 라이브러리를 주역으로 둔다.
/// 앱 설명은 빈 상태에서만 필요하다.
/// CTA 는 `safeAreaInset` 하단 고정 — 스크롤 안에 두면 필름이 늘수록 화면 밖으로 밀린다.
public struct HomeView: View {
    @Environment(AppLanguageStore.self) private var languageStore
    let store: StoreOf<HomeFeature>

    @Query(sort: [SortDescriptor(\Film.createdAt, order: .reverse)])
    private var films: [Film]

    public init(store: StoreOf<HomeFeature> = Store(initialState: HomeFeature.State()) { HomeFeature() }) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            ChalNaNavBar(
                verbatimTitle: "ChalNa",
                trailing: .icon(.settings, accessibilityLabel: "설정") {
                    store.send(.settingsButtonTapped)
                }
            )
            .zIndex(1)

            if films.isEmpty {
                emptyLibrary
            } else {
                libraryGrid
            }
        }
        .chalNaScreen()
        .safeAreaInset(edge: .bottom) { primaryAction }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Empty state

    private var emptyLibrary: some View {
        ScrollView {
            VStack(spacing: 16) {
                ChalNaEmptyState(
                    icon: .film,
                    title: "아직 만든 필름이 없어요",
                    message: "Live Photo와 짧은 영상을 촬영일 순서로 이어붙여\n한 편의 필름처럼 기록해요."
                )

                // 비한국어 UI 에서만 앱 이름 뜻풀이를 덧붙인다. 빈 상태 한정 —
                // 라이브러리가 채워진 뒤에는 설명이 화면을 차지할 이유가 없다.
                if !languageStore.isKoreanUI {
                    ChalNaCard {
                        Text("'찰나'는 아주 짧은 순간이라는 뜻이에요.")
                            .font(ChalNaTypography.label)
                            .foregroundColor(ChalNaColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Library

    private var libraryGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("최근 필름")
                        .font(ChalNaTypography.title)
                        .foregroundColor(ChalNaColor.textPrimary)
                    Spacer()
                    ChalNaTag(String(localized: "\(films.count)편"), variant: .neutral)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                    spacing: 16
                ) {
                    ForEach(Array(films.enumerated()), id: \.element.id) { index, film in
                        Button {
                            store.send(.filmTapped(filmID: film.id))
                        } label: {
                            FilmPosterCard(film: film, fallbackIndex: index)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: "\(film.title), \(film.metaLabel)"))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Primary CTA (하단 고정)

    private var primaryAction: some View {
        Button {
            store.send(.newVlogButtonTapped)
        } label: {
            HStack(spacing: 8) {
                ChalNaIcon(.plus, size: 18, weight: .semibold)
                Text("새 Vlog 만들기")
            }
        }
        .buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(ChalNaColor.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(ChalNaColor.border).frame(height: 1)
        }
        .accessibilityLabel("새 Vlog 만들기")
    }
}

/// 라이브러리 필름 카드.
///
/// 썸네일 비율을 **9:16 으로 맞춘다** — 실제 출력물과 FilmDetail 이 9:16 인데
/// 기존 Home 만 96×54(16:9)라 여기서만 결과물과 다르게 잘려 보였다.
private struct FilmPosterCard: View {
    let film: Film
    let fallbackIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MediaThumb(state: .normal) {
                thumbnail
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: film.title)
                    .font(ChalNaTypography.headline)
                    .foregroundColor(ChalNaColor.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(verbatim: film.metaLabel)
                    .font(ChalNaTypography.caption)
                    .foregroundColor(ChalNaColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = film.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            fallbackPreset.view()
        }
    }

    /// 폴백 프리셋을 12종 전부에서 고른다 (기존에는 6종만 썼다).
    private var fallbackPreset: ThumbnailPreset {
        let pool = ThumbnailPreset.allCases
        return pool[fallbackIndex % pool.count]
    }
}

#Preview("Home — 빈 상태") {
    HomeView()
        .environment(EditSession())
        .environment(AppLanguageStore())
        .modelContainer(for: Film.self, inMemory: true)
}
