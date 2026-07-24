import DesignSystem
import Models
import SwiftUI

// MARK: - 공용 스캐폴드

/// 페이지 공통 레이아웃: 상단 비주얼 존 + 하단 카피 블록.
struct PageScaffold<Visual: View>: View {
    let headline: String
    let body_: String
    @ViewBuilder var visual: () -> Visual

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            visual()
                .frame(maxHeight: .infinity)
            VStack(spacing: 12) {
                Text(headline)
                    .font(ChalNaTypography.title(ChalNaTypography.Size.h1, weight: .bold))
                    .tracking(ChalNaTypography.Tracking.titleKR)
                    .foregroundColor(ChalNaColor.Gray.g900)
                    .multilineTextAlignment(.center)
                Text(body_)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2))
                    .foregroundColor(ChalNaColor.Gray.g500)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
}

/// 9:16 목업 캔버스 (프리뷰 카드 공통).
struct MockCanvas<Content: View>: View {
    var width: CGFloat = 200
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack { content() }
            .frame(width: width, height: width * 16 / 9)
            .background(ChalNaColor.Gray.g200)
            .clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous))
            .chalNaShadow(ChalNaShadow.md)
    }
}

// MARK: - 가치① 필름 소개

struct Value1PageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cellsShown = 0
    @State private var pulsing = false

    var body: some View {
        PageScaffold(
            headline: "찰나의 순간이,\n한 편의 필름으로",
            body_: "Live Photo와 짧은 영상을 이어붙여\n하나의 브이로그가 돼요"
        ) {
            VStack(spacing: 20) {
                MockCanvas(width: 180) {
                    ZStack {
                        ThumbnailPreset.jejuOrange.view()
                        Circle()
                            .fill(ChalNaColor.Purple.p600)
                            .frame(width: 48, height: 48)
                            .overlay(
                                ChalNaIcon(.play, size: 18)
                                    .foregroundColor(.white)
                                    .offset(x: 2)
                            )
                            .scaleEffect(pulsing && !reduceMotion ? 1.06 : 1.0)
                    }
                }
                filmStrip
            }
        }
        .onAppear {
            guard cellsShown == 0 else { return }
            if reduceMotion {
                cellsShown = 5
            } else {
                for i in 1...5 {
                    withAnimation(.easeOut(duration: 0.35).delay(Double(i) * 0.05)) { cellsShown = i }
                }
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulsing = true }
        }
    }

    private var filmStrip: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)
                    .fill(ChalNaColor.Gray.g400)
                    .frame(width: 40, height: 52)
                    .overlay {
                        if index == 0 {
                            RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)
                                .strokeBorder(ChalNaColor.Purple.p600, lineWidth: 2)
                        }
                    }
                    .opacity(index < cellsShown ? 1 : 0)
                    .offset(x: index < cellsShown ? 0 : 24)
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 6)
        .background(
            // 라디우스는 토큰만 — 앱 Timeline 필름스트립과 동일하게 sheet(16).
            RoundedRectangle(cornerRadius: ChalNaRadius.sheet, style: .continuous)
                .fill(ChalNaColor.Gray.g900)
                .frame(height: 64)
        )
    }
}

// MARK: - 맞춤 질문

struct InterestPageView: View {
    let selected: OnboardingInterest
    let onTap: (OnboardingInterest) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let columns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Text("어떤 찰나를 남기고 싶나요?")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h1, weight: .bold))
                .tracking(ChalNaTypography.Tracking.titleKR)
                .foregroundColor(ChalNaColor.Gray.g900)
            Text("딱 맞는 시작을 준비해드릴게요")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2))
                .foregroundColor(ChalNaColor.Gray.g500)

            LazyVGrid(columns: columns, spacing: 13) {
                ForEach(Array(OnboardingInterest.allCases.enumerated()), id: \.element) { index, interest in
                    interestCard(interest)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared || reduceMotion ? 0 : 16)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.06), value: appeared)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)

            Spacer()
        }
        .onAppear { appeared = true }
    }

    private func interestCard(_ interest: OnboardingInterest) -> some View {
        let isSelected = interest == selected
        return Button {
            onTap(interest)
        } label: {
            VStack(spacing: 12) {
                Image(systemName: interest.symbolName)
                    .font(ChalNaTypography.krBody(24))
                    .foregroundColor(ChalNaColor.Purple.p600)
                Text(interest.koreanName)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? ChalNaColor.Purple.p600 : ChalNaColor.Gray.g900)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(
                RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                    .fill(isSelected ? ChalNaColor.Purple.p100.opacity(0.35) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                    .strokeBorder(
                        isSelected ? ChalNaColor.Purple.p600 : ChalNaColor.Gray.g200,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.0 : 0.98)
            .animation(.spring(duration: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

extension OnboardingInterest {
    var symbolName: String {
        switch self {
        case .travel: return "airplane"
        case .daily:  return "sun.max"
        case .family: return "heart"
        case .pet:    return "pawprint"
        }
    }
}

// MARK: - 가치② 촬영일 자동 정렬

struct SortingPageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 뒤섞인 순서 → 0.8초 후 정렬된 순서로 재정렬 (matched move).
    @State private var order: [Int] = [2, 0, 3, 1]
    @State private var markersLit = 0

    private let presets: [ThumbnailPreset] = [.jejuOrange, .seoulSun, .field, .sunset]
    private let dates = ["06.01", "06.02", "", "06.04"]

    var body: some View {
        PageScaffold(
            headline: "고르기만 하세요,\n순서는 찰나가",
            body_: "촬영일 순서로 자동 정렬돼요\n뒤섞인 클립도 걱정 없어요"
        ) {
            VStack(spacing: 28) {
                HStack(spacing: 12) {
                    ForEach(order, id: \.self) { index in
                        RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)
                            .fill(ChalNaColor.Gray.g200)
                            .overlay(presets[index].view().clipShape(RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)))
                            .frame(width: 56, height: 74)
                            .chalNaShadow(ChalNaShadow.sm)
                    }
                }
                timelineBar
            }
        }
        .onAppear {
            guard order != [0, 1, 2, 3] else { return }
            if reduceMotion {
                order = [0, 1, 2, 3]
                markersLit = 4
                return
            }
            Task {
                try? await Task.sleep(for: .seconds(0.8))
                withAnimation(.spring(duration: 0.7)) { order = [0, 1, 2, 3] }
                for i in 1...4 {
                    try? await Task.sleep(for: .seconds(0.15))
                    withAnimation(.easeOut(duration: 0.2)) { markersLit = i }
                }
            }
        }
    }

    private var timelineBar: some View {
        VStack(spacing: 6) {
            ZStack {
                Rectangle()
                    .fill(ChalNaColor.Gray.g200)
                    .frame(width: 260, height: 2)
                HStack(spacing: 62) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < markersLit ? ChalNaColor.Purple.p600 : ChalNaColor.Gray.g200)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            HStack(spacing: 30) {
                ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                    Text(date)
                        .font(ChalNaTypography.monoFallback(11, weight: .medium))
                        .foregroundColor(ChalNaColor.Gray.g500)
                        .frame(width: 38)
                }
            }
        }
    }
}

// MARK: - 가치③ 시간·날짜 라벨 (선택 사항)

struct LabelsPageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var timeShown = false
    @State private var dateShown = false
    @State private var timeToggle = false
    @State private var dateToggle = false

    var body: some View {
        PageScaffold(
            headline: "그날의 시간까지\n함께 기록",
            body_: "영상 위에 시간과 날짜가 자동으로 새겨져요\n필요 없으면 언제든 끌 수 있어요"
        ) {
            VStack(spacing: 16) {
                MockCanvas(width: 200) {
                    ZStack {
                        Text("09:30")
                            .font(ChalNaTypography.keris(40))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                            .opacity(timeShown ? 1 : 0)
                        VStack {
                            Spacer()
                            Text("2026/06/04")
                                .font(ChalNaTypography.keris(11))
                                .foregroundColor(.white)
                                .padding(.bottom, 16)
                                .opacity(dateShown ? 1 : 0)
                        }
                    }
                }
                HStack(spacing: 20) {
                    toggleChip(title: "시간 라벨", isOn: $timeToggle)
                    toggleChip(title: "날짜 라벨", isOn: $dateToggle)
                }
            }
        }
        .onAppear {
            guard !timeShown else { return }
            if reduceMotion {
                timeShown = true; dateShown = true; timeToggle = true; dateToggle = true
                return
            }
            withAnimation(.easeOut(duration: 0.3)) { timeShown = true }
            withAnimation(.easeOut(duration: 0.3).delay(0.15)) { dateShown = true }
            withAnimation(.spring(duration: 0.3).delay(0.45)) { timeToggle = true }
            withAnimation(.spring(duration: 0.3).delay(0.6)) { dateToggle = true }
        }
    }

    private func toggleChip(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(ChalNaTypography.krBody(13, weight: .medium))
                .foregroundColor(ChalNaColor.Gray.g900)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ChalNaColor.Purple.p600)
                .allowsHitTesting(false)   // 데모 전용
                .scaleEffect(0.8)
        }
    }
}

// MARK: - 가치④ 자막

struct SubtitlePageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typed = ""
    @State private var sliderValue: CGFloat = 0.3

    private let fullText = "제주 바다"

    var body: some View {
        PageScaffold(
            headline: "하고 싶은 말은\n자막으로",
            body_: "원하는 클립에 자막을 얹고\n위치와 크기도 자유롭게 바꿔요"
        ) {
            VStack(spacing: 16) {
                MockCanvas(width: 200) {
                    subtitleBox
                }
                sizeSlider
            }
        }
        .onAppear {
            guard typed.isEmpty else { return }
            if reduceMotion {
                typed = fullText
                sliderValue = 0.45
                return
            }
            Task {
                for character in fullText {
                    typed.append(character)
                    try? await Task.sleep(for: .seconds(0.12))
                }
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.spring(duration: 0.5)) { sliderValue = 0.45 }
            }
        }
    }

    /// LabelEditor 박스 스타일 축소판: 흰 배경 + 검정 테두리, 슬라이더와 크기 연동.
    private var subtitleBox: some View {
        let fontSize = 18 + sliderValue * 14
        return Text(typed.isEmpty ? " " : typed)
            .font(ChalNaTypography.krBody(fontSize, weight: .light))
            .tracking(fontSize * -0.06)
            .foregroundColor(.black)
            .padding(.horizontal, fontSize * 0.35)
            .padding(.vertical, fontSize * 0.22)
            .background(Rectangle().fill(Color.white))
            .overlay(Rectangle().strokeBorder(Color.black, lineWidth: fontSize * 0.06))
            .overlay(
                Rectangle()
                    .strokeBorder(ChalNaColor.Purple.p600, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .padding(-4)
            )
    }

    private var sizeSlider: some View {
        HStack(spacing: 8) {
            Text("크기")
                .font(ChalNaTypography.krBody(13, weight: .medium))
                .foregroundColor(ChalNaColor.Gray.g900)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ChalNaColor.Gray.g200).frame(height: 4)
                    Capsule().fill(ChalNaColor.Purple.p600)
                        .frame(width: proxy.size.width * sliderValue, height: 4)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(ChalNaColor.Purple.p600, lineWidth: 1.5))
                        .offset(x: proxy.size.width * sliderValue - 9)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: 130, height: 18)
        }
    }
}

// MARK: - 사진 권한 프라이밍

struct PermissionPageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        PageScaffold(
            headline: "추억을 불러올게요",
            body_: "영상을 만들 때 선택한 사진에만 접근해요.\n전체 보관함 권한은 필요하지 않아요."
        ) {
            VStack(spacing: 40) {
                Circle()
                    .fill(ChalNaColor.Purple.p100.opacity(0.55))
                    .frame(width: 96, height: 96)
                    .overlay(
                        Image(systemName: "photo.on.rectangle")
                            .font(ChalNaTypography.krBody(34))
                            .foregroundColor(ChalNaColor.Purple.p600)
                    )
                    .scaleEffect(appeared || reduceMotion ? 1.0 : 0.8)

                Text("사진을 고르는 시점에 iOS가 접근 여부를 물어봐요")
                    .font(ChalNaTypography.krBody(13))
                    .foregroundColor(ChalNaColor.Gray.g500)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                            .fill(ChalNaColor.Gray.g50)
                    )
                    .padding(.horizontal, 24)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5)) { appeared = true }
        }
    }
}
