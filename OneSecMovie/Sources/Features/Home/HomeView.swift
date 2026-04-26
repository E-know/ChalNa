import SwiftUI
import SwiftData

/// 앱 루트 화면. Moments 커버 · 최근 필름 · Vlog 만들기 CTA.
public struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(EditSession.self) private var session

    /// 사용자가 export 해서 라이브러리에 영구 저장된 필름들. 최근 순.
    @Query(sort: [SortDescriptor(\Film.createdAt, order: .reverse)])
    private var films: [Film]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                cover
                    .padding(.horizontal, MomentsSpacing.lg)
                    .padding(.top, MomentsSpacing.md)

                recentFilmsSection
                    .padding(.top, MomentsSpacing.xxl)

                ScallopDivider()
                    .padding(.horizontal, MomentsSpacing.lg)
                    .padding(.top, MomentsSpacing.xl)

                ctaStack
                    .padding(.horizontal, MomentsSpacing.lg)
                    .padding(.top, MomentsSpacing.xl)
                    .padding(.bottom, MomentsSpacing.xxxl)
            }
        }
        .momentsTopBar(scrollsBehind: true) { header }
        .momentsScreen()
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MOMENTS · 2026")
                    .tagLabel()
                Text("오늘의 순간들")
                    .font(MomentsTypography.krSemibold(15))
                    .foregroundColor(MomentsColor.ink)
            }
            Spacer()
            StampBadge("Draft · v0.1", angle: -6)
        }
    }

    // MARK: - Cover

    private var cover: some View {
        VStack(alignment: .leading, spacing: MomentsSpacing.sm) {
            (Text("Moments")
                .font(MomentsTypography.serifFallback(60, italic: true))
                .foregroundColor(MomentsColor.ink)
             + Text(".")
                .font(MomentsTypography.serifFallback(60, italic: true))
                .foregroundColor(MomentsColor.coral))

            Text("— of your travel")
                .font(MomentsTypography.handFallback(26))
                .foregroundColor(MomentsColor.coral)
                .rotationEffect(.degrees(-2))
                .padding(.leading, MomentsSpacing.xs)

            Text("라이브 포토와 짧은 영상을 촬영일 순서로 이어붙여\n한 편의 필름처럼 기록해요.")
                .font(MomentsTypography.krBody(14))
                .foregroundColor(MomentsColor.taupe)
                .lineSpacing(4)
                .padding(.top, MomentsSpacing.xs)
        }
    }

    // MARK: - Recent films

    private var recentFilmsSection: some View {
        VStack(alignment: .leading, spacing: MomentsSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("RECENT · FILMS")
                    .tagLabel()
                Spacer()
                Text("\(films.count) REEL")
                    .tagLabel(color: MomentsColor.coral)
            }
            .padding(.horizontal, MomentsSpacing.lg)

            if films.isEmpty {
                HandNoteRow("아직 만든 필름이 없어요 ✦ 첫 Vlog를 시작해보세요",
                            tone: .muted, size: 17, alignment: .leading)
                    .padding(.horizontal, MomentsSpacing.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: MomentsSpacing.md) {
                        ForEach(Array(films.enumerated()), id: \.element.id) { idx, film in
                            PolaroidCard(
                                rotation: rotation(for: idx),
                                width: 168,
                                caption: film.title,
                                meta: film.metaLabel,
                                topTape: idx == 0
                            ) {
                                filmCoverContent(for: film, index: idx)
                            }
                        }
                    }
                    .padding(.horizontal, MomentsSpacing.lg)
                    .padding(.vertical, MomentsSpacing.md)
                }
            }
        }
    }

    /// 라이브러리 Film 의 cover 표지. 저장된 thumbnail 이 있으면 이미지로,
    /// 없으면 안전한 fallback 으로 ThumbnailPreset 의 그라데이션을 사용한다.
    @ViewBuilder
    private func filmCoverContent(for film: Film, index: Int) -> some View {
        if let data = film.thumbnailData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            fallbackCoverPreset(for: index).view()
        }
    }

    private func fallbackCoverPreset(for index: Int) -> ThumbnailPreset {
        let pool: [ThumbnailPreset] = [.jejuOrange, .seoulSun, .field, .forest, .sunset, .cafe]
        return pool[index % pool.count]
    }

    // MARK: - CTA

    private var ctaStack: some View {
        VStack(alignment: .leading, spacing: MomentsSpacing.md) {
            Text("START · NEW")
                .tagLabel()

            Button {
                router.push(.mediaPicker)
            } label: {
                HStack(spacing: 8) {
                    MomentsIcon(.plus, size: 14)
                    Text("Vlog 만들기")
                }
            }
            .buttonStyle(.momentsCoral)

            Button("샘플로 먼저 보기") {
                session.replace(clips: SampleData.jejuTimeline, title: SampleData.filmTitle)
                router.push(.timeline)
            }
            .buttonStyle(.momentsText)
        }
    }

    // MARK: - Helpers

    private func rotation(for index: Int) -> PolaroidRotation {
        switch index % 3 {
        case 0: return .left
        case 1: return .center
        default: return .right
        }
    }
}

#Preview("Home") {
    HomeView()
        .environment(AppRouter())
        .environment(EditSession())
        .modelContainer(for: Film.self, inMemory: true)
}
