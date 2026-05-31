# 에디터 WYSIWYG 정합 (커스텀 라벨 위치 보정 + 자동 시간/날짜 라벨 표시) 설계 스펙

- 날짜: 2026-06-01
- 브랜치: `feature/commentLabel`
- 상태: 설계 확정(사용자 승인) → 구현

## 1. 목표
1. **#1** 라벨 위치를 잡을 때 에디터(SwiftUI)와 실제 영상 출력(CATextLayer)의 위치가 일치하도록 보정("살짝 안 맞음" 해소).
2. **#2** 라벨 위치/색 설정 시, 사용자가 설정한 **자동 시간/날짜 라벨**도 에디터·미리보기에 출력과 동일하게 함께 표시.

## 2. 진단 요약 (조사 결과)
- 좌표 정규화·종횡비 소스는 사실상 일치(`clip.displaySize` = `natural.applying(preferredTransform)`, 합성 `placedRect`와 동일 계산).
- #1 원인: SwiftUI `Text`(라인박스 중심) ↔ `CATextLayer`(NSAttributedString.size() 박스, 상단정렬) **텍스트 측정/수직 중심 차이**. 특히 **배경 박스가 있을 때** 에디터는 "패딩 포함 알약"을 중심에 두고 합성은 "텍스트"를 중심에 두고 배경을 덧댐 → 구조적 차이. 코너 라디우스 공식도 상이.
- #2: 합성 자동 라벨 공식 — 시간 `minDim*0.18`, 날짜 `minDim*0.035`, 패딩 `renderSize*0.04`, 스택간격 `minDim*0.02`, 위치 `LabelPosition.origin`(y-up), 같은 구역이면 `stackedOrigins`(시간 위/날짜 아래). 흰색 + 검정 그림자(opacity .5, offset (0,-2), radius 4) + 라벨별 불투명도. 폰트 KERISKEDU. 포맷터 `HH:mm`/`yyyy/MM/dd`(en_US_POSIX, .current).
- 설정: `@Shared(.appStorage("labelTimeEnabled"|"labelTimePosition"|"labelTimeOpacity"|"labelDateEnabled"|"labelDatePosition"|"labelDateOpacity"))`, 기본값 true/.center/0.5/true/.bottomCenter/1.0. `LabelPosition`/`LabelSettings`는 Models(접근 가능). `ChalNaTypography.keris()` 이미 존재.

## 3. 공통 기반 — 단일 진실 공급원 (Models)
신규 `Modules/Models/Sources/LabelLayout.swift`:
- 상수: `timeFontFraction = 0.18`, `dateFontFraction = 0.035`, `paddingFraction = 0.04`, `stackGapFraction = 0.02`.
- `stackedOrigins(position:timeSize:dateSize:gap:renderSize:padding:) -> (time: CGPoint, date: CGPoint)` — 현재 `AVFoundationCompositionService.stackedOrigins`를 **Models로 이동**(동일 로직, y-up 좌하단).
- (`LabelPosition.origin`은 이미 Models에 존재 — 그대로 재사용.)

CompositionService: 로컬 `stackedOrigins` 제거 → `LabelLayout.stackedOrigins` 호출. 하드코딩 분수(0.18/0.035/0.04/0.02)를 `LabelLayout` 상수로 치환. `LabelStackTests`는 `LabelLayout.stackedOrigins`를 검증하도록 갱신.

## 4. DesignSystem — UIFont 접근자
`ChalNaTypography`에 측정용 UIFont 접근자 추가(기존 `memoment()`/`keris()` Font 접근자와 동일 family 해석):
- `memomentUIFont(_ size: CGFloat) -> UIFont` (Memoment 등록 실패 시 `.systemFont(weight:.semibold)`).
- `kerisUIFont(_ size: CGFloat) -> UIFont` (KERIS 실패 시 `.systemFont(weight:.bold)`).
DesignSystem은 Models 비의존이므로 LabelFont는 모름 — LabelFont→UIFont 매핑은 TimelineFeature가 담당.

## 5. #1 커스텀 라벨 위치 보정
### 5.1 측정 통일 — `ClipLabelText` (TimelineFeature)
- 텍스트를 **UIFont로 측정**(custom: `label.font == .memoment ? memomentUIFont : .systemFont(semibold)`; 합성 `measureCustomText`와 동일 UIFont)한 `textSize`로 **고정 프레임**에 렌더 → SwiftUI도 합성과 같은 박스를 중심 기준으로 사용. 렌더 폰트는 기존 `ChalNaTypography.memoment/krBody`(Font) 유지.
- 배경(boxed): 텍스트 고정 프레임 + 패딩(`fontPx*0.35`/`0.22`)이 "알약". 알약이 위치 단위(기존과 동일).

### 5.2 배경 알약 정합 — `CompositionService.makeCustomLabelLayers`
- 배경 있을 때: **알약(=textSize+패딩×2)을 점 기준으로 중심**(`customLabelOrigin`에 pillSize 전달), 텍스트는 알약 안 `(padX, padY)` 위치. 코너 라디우스 `min(fontSize*0.4, 12)`(에디터와 동일 공식).
- 배경 투명: 텍스트를 점 기준 중심(현행).
- 결과적으로 에디터(알약 중심) ↔ 합성(알약 중심)이 같은 기준 → 정합.

## 6. #2 자동 시간/날짜 라벨 오버레이 — `AutoLabelsOverlay` (신규, TimelineFeature)
- 입력: `box: CGSize`(클립 표시 박스), `capturedAt: Date`, 설정(@Shared 동일 키 6개를 뷰가 직접 읽음).
- 계산(합성과 동일, box를 renderSize로 간주):
  - `minDim = min(box.w, box.h)`, `timeFont = minDim*LabelLayout.timeFontFraction`, `dateFont = minDim*LabelLayout.dateFontFraction`, `padding = (box.w*0.04, box.h*0.04)`, `gap = minDim*0.02`.
  - 텍스트 측정: `kerisUIFont` 로 `NSAttributedString.size()`.
  - 위치: 둘 다 켜져 있고 위치 동일 → `LabelLayout.stackedOrigins`; 아니면 각자 `LabelPosition.origin`. (모두 y-up 좌하단 → SwiftUI y-down 변환: `topLeftY = box.h - originY_up - textSize.h`.)
  - 렌더: SwiftUI `Text`(`ChalNaTypography.keris(font)`), 흰색, 그림자(black, radius≈4 비율, y +2 (SwiftUI y-down)), 불투명도 = 해당 라벨 opacity. 각 라벨을 측정 textSize 프레임으로 `.position`(중심).
- 보이기: `timeEnabled`/`dateEnabled` 각각.
- 사용처: `LabelEditorView` 캔버스, `PreviewPanel` — 커스텀 라벨과 함께(자동 라벨은 커스텀 라벨 **아래** 레이어로 그려 커스텀이 위).

## 7. 변경/신규 파일
- 신규: `Modules/Models/Sources/LabelLayout.swift`, `Modules/TimelineFeature/Sources/Components/AutoLabelsOverlay.swift`
- 수정: `Modules/DesignSystem/Sources/Tokens/ChalNaTypography.swift`(UIFont 접근자), `Modules/CompositionService/Sources/CompositionService.swift`(stackedOrigins/상수 → Models, 알약 중심/라디우스), `Modules/CompositionService/Tests/LabelStackTests.swift`(Models 호출), `Modules/TimelineFeature/Sources/Components/ClipLabelText.swift`(UIFont 고정프레임), `Modules/TimelineFeature/Sources/LabelEditorView.swift`(AutoLabelsOverlay), `Modules/TimelineFeature/Sources/Components/PreviewPanel.swift`(AutoLabelsOverlay)

## 8. 작업 분할
- Task 17: Models `LabelLayout` + CompositionService stackedOrigins/상수 치환 + LabelStackTests 갱신 + DesignSystem UIFont 접근자.
- Task 18(#1): CompositionService 알약 중심/라디우스 + ClipLabelText UIFont 고정프레임.
- Task 19(#2): AutoLabelsOverlay + LabelEditorView/PreviewPanel 연결.

## 9. 검증
1. 빌드 성공, 기존 테스트(AppCore 11 + CompositionService 22, stackedOrigins 테스트는 Models 호출로 갱신) 통과.
2. devMock 시각: 자동 라벨이 에디터·미리보기·출력에서 동일 위치/스타일. 커스텀 라벨이 출력과 (거의) 일치, 특히 배경 라벨 정합.
3. 회귀: 자동 라벨 off 시 에디터에 안 보이고 출력도 동일.

## 10. 정직한 한계
SwiftUI ↔ CATextLayer 폰트 렌더 엔진 차이로 측정 통일 후에도 **"거의 일치"**가 목표(완벽 픽셀 일치 아님). 잔여 오차는 1~2회 시각 보정 가능.

## 11. 비범위
- 자동 라벨을 에디터에서 드래그로 이동(설정 화면에서 위치 지정하는 기존 흐름 유지).
- 자동 라벨 폰트/색 커스터마이즈(흰색 고정 + 기존 설정).
