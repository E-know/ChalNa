# 다크 리디자인 후속 항목

2026-07-28 다크 리디자인(27개 태스크 + 전체 브랜치 최종 리뷰)에서 **의도적으로 남긴** 항목들이다.
전부 최종 리뷰에서 검토돼 "머지를 막지 않는다"고 판정됐고, 정확성·데이터 무결성 결함은 하나도 없다.

이 파일이 존재하는 이유: 원래 이 목록은 `.superpowers/sdd/2026-07-28-dark-redesign/` 안에만 있었는데
그 디렉터리는 gitignore 대상이라 사이클이 끝나면 사라진다. 사이클 중에 실제로 같은 일이 있었다 —
직접 작성한 번역 2건의 "원어민 검수 필요" 표시가 그 리포트에만 있어서, `.xcstrings` 의
`state: needs_review` 로 옮긴 적이 있다.

전체 근거·측정값·판정 이유는 `.superpowers/sdd/2026-07-28-dark-redesign/progress.md` 와
`final-review.md` 에 있다(둘 다 gitignore 대상이므로, 사라지기 전에 필요한 것은 여기로 옮겨야 한다).

---

## 1순위 — 검증 장치의 구멍 (가장 가치 큼)

### `ChalNaColorContrastTests` 가 모든 토큰을 `bg` 기준으로만 측정한다

자기 배경을 채우는 컴포넌트는 이 게이트 밖에 있다. **실제로 이 경로로 결함이 통과했다**:
`ChalNaTextField`·`ChalNaTextArea` 가 배경을 `surface` 로 채우는데 placeholder 에
`textTertiary`(토큰 정의상 disabled 전용)를 쓰고 있었다. 스펙이 계산한 3.7:1(vs `bg`)이 아니라
**실제 3.34:1** 로 WCAG AA(4.5) 미달이었고, 녹색 스위트를 그대로 통과했다.

**할 일**: 실제로 렌더되는 조합을 단정하도록 확장한다 — 최소한 `textSecondary`·`textTertiary` ×
`surface`·`surfaceRaised`. 정적 계산이므로 이 하니스에 맞고, 같은 유형을 자동으로 잡는다.

### `.font(.system(` 규칙의 파일 단위 예외 2건을 패턴 단위로 좁힐 수 있는지 검토

`scripts/design-lint.sh:40-47` 이 `ClipLabelText.swift`·`LabelEditorView.swift` 를 예외 처리한다.
예외 자체는 정당하다(라벨이 합성 `CATextLayer` 의 `UIFont` 측정값과 픽셀 단위로 일치해야 해서
Dynamic Type 에 반응하는 역할 토큰을 쓸 수 없다). 문제는 **파일 단위 예외가 영구 맹점**이라는 것 —
앞으로 그 두 파일에 들어오는 어떤 `.font(.system(` 도 검출되지 않는다. Task 21 이 같은 이유로
다른 파일의 예외를 제거한 전례가 있다.

**할 일**: 예외를 `size: fontPx` 같은 패턴 단위로 좁힌다.

---

## 2순위 — 사용자에게 보이는 정리

### `ChalNaBottomBar` 호출처가 0개다

컴포넌트의 자체 문서는 Home·MediaPicker·Export·LabelEditor 가 공유한다고 적혀 있지만, 다섯 화면이
전부 손으로 구현하고 있고 세로 패딩이 **5가지로 갈린다**: 컴포넌트 10/10 · Home 12/12 ·
Export 12/12 · MediaPicker 8/16 · Timeline 8/8 · LabelEditor 10/10. 각자 `bg` + 상단 헤어라인
오버레이까지 따로 복사한다. 최종 리뷰가 "가장 레버리지 큰 정리"로 지목했다.

### 헤더/본문 구분이 한 역할에 3가지 처리

정적 `showsDivider: true` 10화면 · 스크롤 헤어라인 2화면(`MediaPickerView`·`FilmDetailView`) ·
**Home 은 아무것도 없음**. 하나를 골라 Home 에 적용한다.

### `EditToolbar` 의 "라벨" 아이콘

SF Symbol `textformat` 이 스크린샷에서 "가가"처럼 읽히고, 같은 툴바의 다른 20pt 형제들보다
광학적으로 훨씬 크고 무겁게 보인다. 다른 심볼 검토.

---

## 3순위 — 기록만 (조치 판단 필요)

### 필름 커버 썸네일이 합성 영상의 첫 프레임이 아니다

`ExportView` 가 커버를 `clips.first?.thumbnailData` — **첫 소스 클립의 썸네일** — 로 설정한다.
소스 썸네일의 비율은 임의이므로 9:16 박스에 `.fill` 로 그리면 익스포터가 `ClipFraming` 으로
1080×1920 에 센터 크롭하는 방식과 다르게 잘리고, 사용자가 `EditSession.transforms` 로 조정하면 더
벌어진다. 홈·필름상세 포스터가 같은 불일치를 물려받는다.

리디자인 이전부터 있던 결함이고(기존 코드도 `thumbnailView()` 의 기본 `.fill` 을 썼다), 세 에이전트가
독립 확인했다. 시각적 중요도는 **중간** — 가로 클립이거나 사용자 크롭 조정이 있을 때만 눈에 띈다.
고치려면 익스포트된 mp4 에서 `AVAssetImageGenerator` 로 프레임을 뽑아야 하므로 **동작 변경**이고,
그래서 디자인 범위 밖으로 뒀다.

### 프리뷰↔export 계약 잠금의 좁은 잔여 두 가지

`PreviewExportContractTests`(7케이스)가 큰 구멍을 닫았지만:
- 테스트가 `preferredTransform: .identity` 를 넘기고 `naturalSize` 를 `display` 로 먹이므로,
  실제 카메라 클립에서 프리뷰의 `clip.displaySize` 와 익스포트가 내부적으로 유도하는 `displaySize`
  가 일치해야 하는 이음새는 아직 미잠금이다.
- 프리뷰의 pt 공간 매핑(`factor` + `.position`)이 3곳에 중복돼 있고(`PreviewPanel`·`ClipAdjustView`·
  `LabelEditorView`) 테스트가 없다.

### 직접 작성한 번역 2건 — 원어민 검수 필요

`초기화` 와 ClipAdjust 드래그 힌트의 en/ja 는 번역자가 아니라 우리가 작성했다. `Localizable.xcstrings`
에서 `state: needs_review` 로 표시해 Xcode String Catalog 가 검수 대상으로 보여준다.

### Minor (기하)

- `ClipFraming.resolvedRect` 가 `transform.scale` 을 `[1,4]` 로 클램프하지 않는데
  `CompositionService` 는 한다. `EditSession.setTransform` 은 검증이 없다 — 불변식이
  `ClipAdjustView.swift:248` 관례로만 유지된다.
- `ClipAdjustView.resolvedRectUnclamped` 가 `resolvedRect` 의 산식을 복제하고 테스트가 없다.
- `1080×1920` 이 4곳에 하드코딩돼 있다. 프리뷰 매핑은 그 **크기**에는 불변이지만(증명됨)
  **비율**에는 불변이 아니다. 자연스러운 위치는 `Models`.

### trait 수준 접근성은 자동 게이트 밖이다 — 하니스 한계

VoiceOver 출력은 이 환경에서 실행할 수 없다. 정적으로 계산 가능한 접근성(대비)은 게이트 안에 있지만,
`.isSelected` 같은 trait 은 **163개 테스트 중 어느 것도** 단정하지 않는다. `ChalNaListRow` 의 선택
상태 수정은 소스 근거로만 검증됐다("VoiceOver 가 선택됨을 읽는다"는 반증 관찰은 실행 불가). 실기기
VoiceOver 패스가 가능해지면 언어 선택 화면이 첫 확인 대상이다.

---

## 이 사이클에서 가장 중요한 교훈

> 성공 기준이 실행 불가능한 수정에 빌드·테스트·lint 의 녹색이 대체물로 들어갔다.
> **lint 녹색은 철자를 보증했는데 의미로 읽혔고, 빌드 녹색은 컴파일을 보증했는데 접근성으로 읽혔다.**

이 브랜치의 검증 실패가 전부 같은 모양이었다 — 도달 불가한 Showcase, 충족 불가한 lint 규칙, 앱에
닿지 않는 `simctl ui content-size`, 어느 로그에도 닿지 않는 `print()`, 어떤 스크립트든 0 을 내는
`/tmp` 에서의 lint 실행, 접근성 트리 제거로 오해한 `.opacity(0)`, 그리고 유닛 스위트가 빠진
"전체 테스트". **독립 재계산에서 살아남은 발견은 전부 정적으로 계산 가능한 것들이었다.**

**규칙**: 수정을 받아들이기 전에 그 성공 기준을 명시한다. 그 기준이 이 환경에서 실행 불가하면
그렇다고 말하고 "소스 근거"로 표시한다 — 빌드·테스트·lint 녹색을 대체물로 세우지 않는다.
