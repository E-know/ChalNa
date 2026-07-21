import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem
import SwiftData

/// 앱 루트 화면. Vlog 만들기 CTA + 최근 필름 라이브러리.
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
            header
                .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    hero
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    primaryAction
                        .padding(.horizontal, 24)

                    recentFilmsSection
                        .padding(.bottom, 64)
                }
            }
        }
        .chalNaScreen()
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(verbatim: "ChalNa")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ChalNaColor.Gray.g900)
                Spacer()
                Button {
                    store.send(.settingsButtonTapped)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundColor(ChalNaColor.Gray.g900)
                }
                .buttonStyle(.chalNaHeaderAction)
                .accessibilityLabel("설정")
            }
            .padding(.horizontal, 16)

            Spacer()

            Divider()
                .overlay(ChalNaColor.Purple.p400)
        }
        .frame(height: 40)
        .background(Color.white)
        .padding(.bottom, 4)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘 찰나의 순간들")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ChalNaColor.Gray.g900)
            Text("Live Photo와 짧은 영상을 촬영일 순서로 이어붙여\n한 편의 필름처럼 기록해요.")
                .font(.system(size: 16))
                .foregroundColor(ChalNaColor.Gray.g500)
                .lineSpacing(4)
            // 비한국어 UI 에서만 앱 이름 '찰나(ChalNa)' 뜻풀이를 옅은 surface 박스로 구분해 덧붙인다.
            if !languageStore.isKoreanUI {
                Text("'찰나'는 아주 짧은 순간이라는 뜻이에요.")
                    .font(.system(size: 14))
                    .foregroundColor(ChalNaColor.Gray.g500)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                            .fill(ChalNaColor.Gray.g50)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                            .strokeBorder(ChalNaColor.Gray.g200, lineWidth: 1)
                    )
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Primary CTA

    private var primaryAction: some View {
        Button {
            store.send(.newVlogButtonTapped)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("새 Vlog 만들기")
            }
        }
        .buttonStyle(.chalNa(.filled, size: .xl, fillWidth: true))
        .accessibilityLabel("새 Vlog 만들기")
    }

    // MARK: - Recent films

    private var recentFilmsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("최근 필름")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ChalNaColor.Gray.g900)
                Spacer()
                Text("\(films.count)편")
                    .font(.system(size: 14))
                    .foregroundColor(ChalNaColor.Gray.g500)
            }
            .padding(.horizontal, 24)

            if films.isEmpty {
                emptyState
                    .padding(.horizontal, 24)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(films.enumerated()), id: \.element.id) { idx, film in
                        Button {
                            store.send(.filmTapped(filmID: film.id))
                        } label: {
                            FilmRow(film: film, fallbackIndex: idx)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("아직 만든 필름이 없어요.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ChalNaColor.Gray.g900)
            Text("첫 Vlog를 시작해보세요.")
                .font(.system(size: 15))
                .foregroundColor(ChalNaColor.Gray.g500)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .fill(ChalNaColor.Gray.g50)
        )
    }
}

/// 라이브러리 필름 1행 (다나와 list item 패턴: 좌측 16:9 썸네일 · 중앙 텍스트 · 우측 chevron).
private struct FilmRow: View {
    let film: Film
    let fallbackIndex: Int

    var body: some View {
        HStack(spacing: 16) {
            thumbnail
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)
                        .strokeBorder(ChalNaColor.Gray.g100, lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(film.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ChalNaColor.Gray.g900)
                    .lineLimit(1)
                Text(film.metaLabel)
                    .font(.system(size: 14))
                    .foregroundColor(ChalNaColor.Gray.g500)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ChalNaIcon(.chevronRight, size: 16)
                .foregroundColor(ChalNaColor.Gray.g400)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .strokeBorder(ChalNaColor.Gray.g100, lineWidth: 1)
        )
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

    private var fallbackPreset: ThumbnailPreset {
        let pool: [ThumbnailPreset] = [.jejuOrange, .seoulSun, .field, .forest, .sunset, .cafe]
        return pool[fallbackIndex % pool.count]
    }
}

#Preview("Home") {
    HomeView()
        .environment(EditSession())
        .environment(AppLanguageStore())
        .modelContainer(for: Film.self, inMemory: true)
}
