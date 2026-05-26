import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem
import SwiftData

/// 앱 루트 화면. Vlog 만들기 CTA + 최근 필름 라이브러리.
public struct HomeView: View {
    @Environment(AppRouter.self) private var router
    let store: StoreOf<HomeFeature>

    @Query(sort: [SortDescriptor(\Film.createdAt, order: .reverse)])
    private var films: [Film]

    public init(store: StoreOf<HomeFeature> = Store(initialState: HomeFeature.State()) { HomeFeature() }) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .chalNaHeaderBar(scrollProgress: store.scrollProgress)
                .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    hero
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .trackScrollOffset(in: "home-scroll")

                    primaryAction
                        .padding(.horizontal, 24)

                    recentFilmsSection
                        .padding(.bottom, 64)
                }
            }
            .coordinateSpace(name: "home-scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                let p = offset / 8
                withAnimation(.easeInOut(duration: 0.15)) {
                    store.send(.scrollProgressChanged(p))
                }
            }
        }
        .chalNaScreen()
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("ChalNa")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h1))
                .foregroundColor(ChalNaColor.ink)
            Spacer()
            Button {
                store.send(.settingsButtonTapped)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(ChalNaColor.ink)
            }
            .buttonStyle(.chalNaHeaderAction)
            .accessibilityLabel("설정")
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘의 순간들")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h1, weight: .bold))
                .foregroundColor(ChalNaColor.ink)
            Text("Live Photo와 짧은 영상을 촬영일 순서로 이어붙여\n한 편의 필름처럼 기록해요.")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                .foregroundColor(ChalNaColor.taupe)
                .lineSpacing(4)
        }
    }

    // MARK: - Primary CTA

    private var primaryAction: some View {
        Button {
            store.send(.newVlogButtonTapped)
            // 임시: navigation 은 여전히 router 가 처리. Step 6 에서 AppFeature.StackState 로 통합 예정.
            router.push(.mediaPicker)
        } label: {
            HStack(spacing: 8) {
                ChalNaIcon(.plus, size: 16)
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
                    .font(ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .semibold))
                    .foregroundColor(ChalNaColor.ink)
                Spacer()
                Text("\(films.count)편")
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
                    .foregroundColor(ChalNaColor.taupe)
            }
            .padding(.horizontal, 24)

            if films.isEmpty {
                emptyState
                    .padding(.horizontal, 24)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(films.enumerated()), id: \.element.id) { idx, film in
                        Button {
                            router.push(.filmDetail(filmID: film.id))
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
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body, weight: .medium))
                .foregroundColor(ChalNaColor.ink)
            Text("첫 Vlog를 시작해보세요.")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2))
                .foregroundColor(ChalNaColor.taupe)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .fill(ChalNaColor.ivory)
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
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body, weight: .semibold))
                    .foregroundColor(ChalNaColor.ink)
                    .lineLimit(1)
                Text(film.metaLabel)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.small))
                    .foregroundColor(ChalNaColor.taupe)
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
        .environment(AppRouter())
        .environment(EditSession())
        .modelContainer(for: Film.self, inMemory: true)
}
