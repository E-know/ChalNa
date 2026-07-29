# ChalNa 앱 전면 리디자인 — 설계 문서

작성일: 2026-07-28
기준 커밋: `51b3f2e` (develop, 빌드 그린 확인됨)

## 1. 배경과 문제 정의

ChalNa는 Live Photo·영상을 촬영일 순서로 이어 붙여 9:16 세로 Vlog를 만드는 iOS 앱이다.
현재 디자인 시스템은 식별자만 `ChalNa`이고 **값은 "Danawa DDS Mobile v2.0"(가격비교 커머스 DDS)** 이 이식돼 있다.

0부터 다시 판단한 결과, 손질이 아니라 **시각 언어를 새로 정의해야 하는 상태**다.

### 1.1 핵심 불일치

| 관찰 | 문제 |
|---|---|
| Primary `#8B38E5`, radius 4px, gray hairline 리스트 아이템 | 커머스 상품목록 문법. 메모리 보관 앱과 무관 |
| 화면 배경 순백 + 라이트 하드코딩(`Color.white` 60곳), `UIUserInterfaceStyle: Light` 강제 | 사진·영상 썸네일이 배경에 밀려 대비를 잃음 |
| 프리뷰/크롭 캔버스와 필름스트립만 검정 | 라이트 화면 한복판에 검은 섬. 국소적 모순이 이미 발생 |
| Splash만 `Purple.p900` 다크 + KERISKEDU | 첫인상과 본문이 완전 단절 |

### 1.2 브랜드 앵커

앱 아이콘은 **인디고 바이올렛 `#462DE2` 배경 + 흰 카메라 + 반짝임(찰나=섬광)** 이다.
Splash도 `Purple.p900`(= `#462DE2`)을 쓴다. 즉 **이 앱의 진짜 브랜드 색은 아이콘의 인디고**이고,
다나와 계열 `Purple.p600 #8B38E5`(마젠타 쪽 보라)가 나중에 끼어든 이물질이다.
액센트는 새로 발명하지 않고 아이콘에서 역산한다.

## 2. 확정된 결정

| 결정 | 값 | 근거 |
|---|---|---|
| 시각 방향 | **다크 시네마틱** | 화면 대부분이 사용자 사진·영상을 보여준다. 순백 배경은 썸네일 밝은 영역과 경계가 사라져 대비를 깎는다. 캔버스가 이미 검정이라 다크 통일이 기존 모순을 해소한다 |
| 모드 범위 | **다크 전용** (`UIUserInterfaceStyle: Dark`) | 사진/영상 편집 앱 업계 통상(CapCut, VN, Darkroom, Halide). 토큰이 한 짝이라 대비·가독성 버그가 원천 차단되고 검증 비용이 절반 |
| 정보 구조 | **현 플로 유지 + 화면 단위 재설계** | 홈→선택→편집→저장 단일 스택은 단일 작업(Vlog 만들기)에 이미 맞는 형태. 탭바를 달 이유가 없다. TCA 네비/delegate 구조를 남겨 회귀 리스크를 줄인다 |
| 사상구조 | **시맨틱 토큰 신설 + 화면 전면 재작성** | 값만 스왑하면 `g50`이 어두워지는 모순된 이름이 남고 `Color.white` 60곳은 그대로 흰색으로 밝아진다. 레이아웃·위계·접근성 버그도 하나도 해결되지 않는다 |
| UI 폰트 | 시스템 폰트. KERISKEDU는 브랜드 순간(Splash·영상 라벨 미리보기) 전용 | KERISKEDU Line은 아웃라인(속이 빈) 서체로 작은 크기 가독성이 무너진다 |

## 3. UI 깨짐 감사 (코드 기반, 24건)

리디자인이 반드시 해소해야 하는 목록. 번호는 이후 계획에서 참조한다.

### 3.1 확정 렌더 버그

| # | 위치 | 증상 |
|---|---|---|
| 1 | `LabelPositionSettingsView.swift:96` | `lineWidth: isSelected ? 0 : 10` — 비선택 셀에 10pt 테두리. 1pt 오타 |
| 2 | `ChalNaNavigationBar.swift:104` | 닫기(X) 글리프 `frame(height: 33)`. 같은 바의 back chevron은 10pt. 44pt 바를 뚫는다 |
| 3 | `HomeView.swift:69` | 헤더 `frame(height: 40)` 안에 minHeight 44 버튼 + 24pt 타이틀 + Spacer + Divider → 프레임 초과 |
| 4 | `FilmStripCollectionView.swift:71` | `UIColor(named: "ChalNaInk")`는 항상 nil. colorset은 DesignSystem.framework 번들에 있고 `UIColor(named:)` 기본 조회는 `Bundle.main`(앱) → `?? .black`으로 낙하. 라이트 화면에 순검정 띠가 **우연히** 박혀 있다 |
| 5 | `DesignSystem/Resources/ChalNaColors.xcassets` | colorset 7개 전부 dead. `ChalNaColor`는 hex 리터럴로만 정의됨. CLAUDE.md 서술과 불일치 |

### 3.2 레이아웃 오버플로우

| # | 화면 | 내용 |
|---|---|---|
| 6 | Timeline | 고정 높이 합계 ≈741pt (헤더 68 + 프리뷰 352 + 트랜스포트 60 + 라벨행 35 + 스트립 112 + 힌트 34 + 툴바 80). iPhone SE 가용 ≈647pt → **94pt 초과**. `Spacer(minLength: 0)`는 고정 높이를 줄이지 못한다 |
| 7 | Export | `reservedHeight` 210/300/290 하드코딩 + `coverWidth` 하한 240pt → SE `.done`에서 커버 427pt + 상태 + CTA > 가용 579pt |
| 8 | Timeline·FilmDetail | 프리뷰/포스터 300pt 고정 (기기 무관) |
| 9 | LabelEditor | `sliderRowHeight = 84` 고정 예약 — 키보드·세이프에어리어 조합에 따라 캔버스 과축소 |

### 3.3 접근성

| # | 내용 |
|---|---|
| 10 | **Dynamic Type 대응 0.** 전부 `Font.system(size:)` 고정 pt(`relativeTo:` 없음). 큰 글씨 설정이 무시된다 |
| 11 | `tagLabel()`이 SF Mono 12pt인데 **한글**을 담는다. SF Mono에 한글 글리프가 없어 폴백되며 자간·베이스라인이 어긋난다 |
| 12 | 8pt(`monoFallback(8)`, "영상 X")·11pt(`krBody(11)`, DevMediaAssetCard) 폰트. 자체 가이드("11px 이하 금지")를 스스로 위반 |

### 3.4 토큰 규율

| # | 내용 |
|---|---|
| 13 | `.font(.system(...))` 직접 호출 18곳 (HomeView, SettingsView, ChalNaNavigationBar, LabelPositionSettingsView) |
| 14 | `cornerRadius: 8` 리터럴 (`SettingsView.swift:52,56`) |
| 15 | 파괴적 액션 색 불일치 — EditToolbar 삭제 = `Purple.p600`(=Primary), FilmDetail 삭제 = `danger` |
| 16 | legacy 폰트 stub 4종(`displayEN`/`serifFallback`/`hand`/`handFallback`) + 버튼 별칭 2종(`chalNaCoral`/`chalNaOutline`) 잔존. **다수 호출처가 아직 별칭을 쓴다** |
| 17 | 아이콘 3계통 혼재 — 커스텀 Lucide 패스 20종(1.5pt 고정 stroke) + `.rotate`/`.textLabel`만 SF Symbols(`.resizable()`) + `ChalNaChip` 내부에서 또 SF Symbols. **같은 EditToolbar에서 선 굵기가 다르게 보인다** |
| 18 | 타이포 스케일 밖 숫자 난립 — 8·10·11·13·22·26·40·48. `ChalNaTypography.Size` enum이 사실상 무시됨 |
| 19 | 헤더 패턴 3종 — `ChalNaNavigationBar + chalNaHeaderBar`(대부분) / HomeView 자체 헤더 / ExportView 자체 헤더 |
| 20 | `ChalNaNavigationBar` 중앙 타이틀이 ZStack 오버레이라 폭 제한이 없다. Timeline의 subtitle(=사용자 입력 제목)이 길면 back 버튼과 겹친다 |
| 21 | `UIUserInterfaceStyle: Light` 강제 + `Color.white` 하드코딩 60곳 |

### 3.5 정보 위계

| # | 내용 |
|---|---|
| 22 | Home — 히어로 카피 3줄이 CTA·라이브러리를 압도. 앱의 자산(만든 필름)이 스크롤 아래. CTA가 스크롤 안에 있어 필름이 늘면 화면 밖으로 밀린다. **Home 썸네일이 96×54(16:9)인데 실제 출력물과 FilmDetail은 9:16** — Home에서만 결과물과 비율이 다르게 잘려 나온다 |
| 23 | MediaPicker — 제목 입력이 사진 선택보다 앞. 영문 tagLabel("PICK · YOUR CHALNA", "TITLE · …")이 i18n 3개 언어에서 고정 영문 |
| 24 | Export — 커버와 진행률이 분리돼 시선 분산. 완료 CTA 4개가 2×2로 동등하게 놓여 주 액션이 불명확 |

## 4. 토큰 체계

### 4.1 색 — 다크 전용 시맨틱

수치 스케일(`Purple.p100…p900`, `Blue.b50…b900`, `Gray.g50…g900`, `Chip.*`)은 **삭제**한다.
화면은 역할 이름만 쓴다.

```swift
ChalNaColor.bg             #0B0A10   // 화면 배경 — 무채색 아닌 아주 옅은 인디고 캐스트
ChalNaColor.surface        #16151D   // 카드 / 리스트 행
ChalNaColor.surfaceRaised  #201F29   // 바텀시트 / 플로팅 툴바
ChalNaColor.canvas         #000000   // 영상·크롭 캔버스 (진짜 검정 유지)
ChalNaColor.border         #2C2A38   // 1px hairline
ChalNaColor.borderStrong   #3D3A4D   // 입력 필드 / 강조 경계
ChalNaColor.textPrimary    #F5F4F7   // 순백 아님 — 다크에서 순백은 헐레이션
ChalNaColor.textSecondary  #A3A0AE
ChalNaColor.textTertiary   #6B6878   // disabled 전용
ChalNaColor.accent         #8B7BFF   // 텍스트·아이콘·스트로크
ChalNaColor.accentFill     #5B45E8   // 면형 버튼 배경
ChalNaColor.accentPressed  #A091FF
ChalNaColor.onAccent       #FFFFFF
ChalNaColor.danger         #FF6B66   // 다크용으로 밝힌 레드
ChalNaColor.success        #3DD9A0
ChalNaColor.brandDeep      #462DE2   // 브랜드 서피스 = 앱 아이콘 색 그 자체
ChalNaColor.scrim          black 60%
```

설계 의도 두 가지:

1. **`bg`(#0B0A10)와 `canvas`(#000)를 거의 같은 밝기로 둔다.** 감사 #4(검은 필름스트립 띠), 그리고 흰 화면에 검은 캔버스가 박히는 국소 모순이 구조적으로 사라진다.
2. **브랜드 색과 인터랙션 색을 분리한다.** 아이콘의 `#462DE2`는 `bg` 대비 약 2.4:1로 버튼에 쓸 수 없다. 밝힌 `accent`를 인터랙션에, 원본은 Splash·브랜드 면에만 쓴다.

측정된 대비:

| 조합 | 비율 | 판정 |
|---|---|---|
| `textPrimary` / `bg` | 17.6:1 | 통과 |
| `textSecondary` / `bg` | 7.7:1 | 통과 |
| `onAccent` / `accentFill` | 6.0:1 | 버튼 라벨 통과 |
| `accent` / `bg` | 5.9:1 | 본문 텍스트 통과 |
| `textTertiary` / `bg` | 3.7:1 | 본문 기준(4.5) 미달 → **disabled 전용.** WCAG 비활성 요소 예외이며, 활성 텍스트에 쓰지 않는다 |
| `brandDeep` / `bg` | 2.4:1 | **인터랙션에 사용 금지.** Splash·브랜드 면 전용 |

### 4.2 깊이 — 그림자 대신 밝기 단계

다크에서는 그림자가 거의 보이지 않는다. `bg → surface → surfaceRaised` 3단 밝기 + 1px hairline으로 표현한다.

```swift
ChalNaShadow.floating = (black 50%, blur 24, y 8)   // 유일한 그림자 — 떠 있는 툴바 전용
```

기존 `sm`/`md`/`lg` 3종과 `chalNaShadow` 5곳 남발을 제거한다.

### 4.3 타이포 — 역할 6종 + mono + keris

전부 `relativeTo:`를 붙여 Dynamic Type을 연다.

```swift
.display   28 bold      relativeTo .largeTitle   // 화면 대제목
.title     22 semibold  relativeTo .title2       // 섹션 제목
.headline  17 semibold  relativeTo .headline     // 카드 제목 · 버튼
.body      16 regular   relativeTo .body
.label     13 medium    relativeTo .footnote     // 메타 · 태그 (기존 tagLabel 대체)
.caption   12 regular   relativeTo .caption
.mono(_)   SF Mono                               // 타임코드·퍼센트 등 순수 숫자 전용
.keris(_)  KERISKEDU                             // Splash · 영상 라벨 미리보기 전용
```

- `tagLabel()`의 **SF Mono를 걷어낸다** → 감사 #11 해소. mono는 `00:12 / 01:40`, `47%` 같은 숫자에만.
- 8pt·11pt 제거, 최소 12pt (감사 #12).
- 앱 전역 `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` 클램프.
  근거: Timeline/Export는 9:16 캔버스가 레이아웃을 지배해 무제한 확대를 수용할 수 없다.
  상한을 두고 그 안에서 실제로 동작하게 만드는 편이, 확대를 통째로 무시하는 현재보다 정직하다.
- legacy stub 4종·버튼 별칭 2종 **삭제**, 호출처 전부 교체 (감사 #16).

### 4.4 라디우스 · 여백 · 모션

```swift
ChalNaRadius.xs 6 / .sm 10 / .md 14 / .lg 20 / .pill 999
```

4px 단위(커머스 카드 문법)를 버리고 미디어 카드에 맞게 키운다.

여백은 CLAUDE.md 규칙대로 **리터럴 숫자**를 유지하되 리듬을 4/8/12/16/20/24로 통일하고,
**화면 좌우 여백을 20 하나로** 맞춘다 (현재 헤더 16 / 본문 24가 섞여 시각 좌측선이 두 개다).

```swift
ChalNaMotion.fast     = .easeOut(duration: 0.15)                          // 상태 토글
ChalNaMotion.standard = .easeInOut(duration: 0.24)
ChalNaMotion.spring   = .spring(response: 0.35, dampingFraction: 0.85)    // 스냅백 — 기존 검증값 유지
```

### 4.5 부수 정리

- dead colorset 7개 삭제 (감사 #5)
- `Info.plist UIUserInterfaceStyle: Light → Dark` (감사 #21)
- `UIColor(named:)` 조회를 토큰 참조로 교체 (감사 #4)

## 5. 컴포넌트 인벤토리

대상 화면 표면은 **14개**다: 루트 `home` + 스택 10개(`mediaPicker`·`timeline`·`export`·`filmDetail`·`settings`·`labelSettings`·`labelPosition`·`support`·`clipAdjust`·`language`) + `Splash` + `LabelEditor`(fullScreenCover) + `MediaPreviewSheet`(sheet).

이 14개가 실제로 필요로 하는 것만 남긴다. 괄호 안은 현재 실사용 횟수.

### 5.1 크롬

| 컴포넌트 | 설계 |
|---|---|
| `chalNaScreen()` | `bg` 풀블리드. 유지, 색만 교체 |
| **`ChalNaNavBar`** | **재작성.** ZStack 중앙 오버레이를 버리고 `HStack { 좌슬롯 · 타이틀(가변, lineLimit 1) · 우슬롯 }`. 슬롯은 좌우 **고정 56pt**(44pt 액션 버튼 + 6pt 여백 × 2)이며 액션이 없어도 폭을 유지해 타이틀이 항상 광학적 중앙에 온다. 타이틀이 버튼 영역을 물리적으로 침범할 수 없다 → 감사 #20 구조적 해결. 높이 52 |
| **`ChalNaNavAction`** | 좌·우 액션 단일 컴포넌트. `.back / .close / .text(키) / .icon(kind)`. **호출처가 글리프 크기를 지정할 수 없다** → 감사 #2 재발 불가 |
| `chalNaScrollHairline(progress:)` | `chalNaHeaderBar`(11곳) 대체. 배경 페이드 제거(배경이 이미 `bg`라 무의미), hairline만 |

### 5.2 액션

| 컴포넌트 | 설계 |
|---|---|
| **`ChalNaButton`** | variant 5종 → **3종**(`.primary` accentFill / `.secondary` surface+border / `.ghost` accent 텍스트) + `destructive: Bool` 플래그. **각 호출처가 "삭제는 무슨 색?"을 판단하지 않게** 되어 감사 #15가 선택지에서 사라진다. 사이즈 `.lg 52 / .md 44 / .sm 36` |
| **`ChalNaBottomBar`** | 하단 2버튼 푸터. 세이프에어리어 inset + 상단 hairline을 한 곳에서 처리 |

### 5.3 콘텐츠

| 컴포넌트 | 설계 |
|---|---|
| **`ChalNaCard`** | `surface` + `md` + border. 손으로 쌓은 `RoundedRectangle().fill().overlay(strokeBorder())` **8곳** 흡수 |
| **`ChalNaListRow`** | `.navigate` / `.toggle` / `.slider` / `.check` / `.plain`. Settings·LabelSettings·Language의 손작성 행 빌더 4개 대체. 최소 높이·터치 영역·비활성 톤이 한 곳에서 결정 |
| **`ChalNaTag`** | `ChalNaChip`(10곳) 대체. 다크에서 반투명 흰 필 + 10pt 글리프. `.live`(`danger` dot — Live Photo 관례인 붉은 계열) / `.video` / `.neutral` / `.accent`. **Chip 내부가 SF Symbols를 직접 쓰던 이중 계통 제거** |
| **`MediaThumb`** | `ClipThumbCard`(3곳) 대체. 상태 6종(`normal`/`selected`/`playing`/`lifted`/`ghost`/`dimmed`) 전부 유지 — `lifted`·`ghost`는 필름스트립 long-press 드래그가 쓴다. 선택 링은 `accent` + 안쪽 어두운 stroke **이중선** — 밝은 썸네일에서도 링이 사라지지 않게 |
| **`ChalNaCanvas`** | 9:16 미디어 캔버스. 현재 Timeline 프리뷰·ClipAdjust·LabelEditor **세 곳이 `fittedBox` + `Color.black` + clipShape를 거의 똑같이 재구현**. 하나로 통합 (기하 SSOT는 기존 `LabelBoxGeometry`/`ClipFraming` 유지) |
| `ChalNaProgressBar` | Export 진행률 |
| `ChalNaEmptyState` | Home 빈 상태 · FilmDetail 필름 없음 |
| `ChalNaNotice` | "영상 파일을 찾을 수 없어요" 안내 카드 |
| `ChalNaToast` | Export 저장 토스트 |
| `ChalNaBlockingOverlay` | MediaPicker 사진 추출 오버레이 |
| `ChalNaTextField` (1곳) | 다크 재스타일 |
| `ChalNaTextArea` | 신설 — Support의 `TextEditor` + 수동 플레이스홀더 오버레이 대체 |
| `ChalNaSlider` | 다크 트랙/노브 (LabelSettings 투명도, LabelEditor 크기) |

### 5.4 아이콘 — SF Symbols 단일화

현재 3계통이며 **같은 EditToolbar 안에서 "조정"(커스텀 패스)과 "라벨"(SF Symbol)의 선 굵기가 다르게 보인다**(감사 #17).

SF Symbols로 가는 근거:

- optical sizing·weight가 옆 텍스트와 자동으로 맞는다. 커스텀 패스는 1.5pt 고정이라 12pt 라벨 옆에서도, 28pt 아이콘 옆에서도 같은 굵기 — 작은 크기에서 뭉개지고 큰 크기에서 얄팍하다.
- Dynamic Type을 따라 커진다 (감사 #10과 직결).
- VoiceOver 기본 이름이 붙는다.
- 커스텀 20종의 optical 밸런스를 손으로 맞추려면 기준값이 필요한데 코드에 근거가 없다(전부 1.5pt 일괄).

`ChalNaIconKind` enum과 **호출부 41곳의 형태는 그대로 유지**하고 내부 매핑만 SF Symbols + weight 연동으로 교체한다. 호출처 변경은 0.

### 5.5 삭제

| 대상 | 근거 |
|---|---|
| `ChalNaBottomSheet` | **실사용 0곳.** 완전한 dead code |
| `LiveBadge` | 실사용 1곳(`FilmStripCollectionView.swift:146`)뿐이고 `ChalNaTag(.live)`과 역할 중복 |
| `ChalNaHeaderActionButtonStyle` | `ChalNaNavAction`에 흡수 |
| `ChalNaColor.Purple/Blue/Gray/Chip` | 시맨틱 토큰으로 대체 |
| `ChalNaShadow.sm/md/lg` | `.floating` 하나로 |
| dead colorset 7개 | 아무도 읽지 않음 |

`DesignSystemShowcaseView`는 **유지·재작성**한다 — 토큰·컴포넌트 전수를 한 화면에서 확인하는 회귀 검증 수단이라 이번 규모의 변경에서 값이 크다.

## 6. 화면별 재설계

### 6.1 Splash

`brandDeep` 풀배경 → **`bg` + 아이콘 뒤 `brandDeep` 라디얼 글로우**.
글로우 방식이면 Splash가 이미 본문의 어둠 위에 있어 전환이 이어진다.
아이콘의 `shadow(color: .white, radius: 4)`(흰 후광)는 로고 외곽을 뭉개므로 제거.
`reduceMotion` 대응은 기존 유지.

### 6.2 Home — 위계 반전 (감사 #3, #22)

- 히어로 카피 **삭제**. 앱 설명은 빈 상태에서만 필요하다. 비한국어 UI의 "'찰나' 뜻풀이" 박스도 **빈 상태 한정**으로 이동(현재는 항상 떠서 히어로를 더 길게 만든다).
- 라이브러리를 첫 화면 주역으로: **2열 9:16 포스터 그리드**. 현재 `96×54`(16:9)는 실제 출력물·FilmDetail(9:16)과 비율이 달라 `scaledToFill`로 잘려 나온다.
- CTA "새 Vlog 만들기"를 **`safeAreaInset` 하단 고정**. 현재는 스크롤 안에 있어 필름이 늘면 화면 밖으로 밀린다.
- 헤더 `frame(height: 40)` → `ChalNaNavBar` 52pt.
- 폴백 `ThumbnailPreset`을 6종 → **12종 전부**로 확대.

### 6.3 MediaPicker — 순서 반전 (감사 #23)

- 본문 순서: **① 사진 추가 → ② 선택 그리드 → ③ 제목**. 고른 다음 이름을 붙이는 게 자연스럽다.
- **제목 필드는 선택이 1개 이상일 때만 노출** (0개일 때 제목을 물을 이유가 없다).
- 서브타이틀 `LIVE · VIDEO` 삭제(정보가치 없음). 영문 태그 전부 로컬라이즈 카피로 교체.
- 그리드 셀: 3열 `flexible` 안의 `84×108` 고정 크기(폭 불일치) → `aspectRatio(9/16)`로 열 폭을 따르게. 칩을 억지로 맞춘 `scaleEffect(0.78) + offset(x:-5, y:-7)` 제거.
- 제거(X) 배지 히트 40pt → 44pt.
- 로딩 오버레이 → `ChalNaBlockingOverlay`. 진행 카운트 mono 유지(순수 숫자).

### 6.4 MediaPreviewSheet

`Color.white` 배경 → `surfaceRaised`. `aspectRatio` + `maxHeight: 380` 조합을 화면 비율 기반으로 재조정. 칩 → `ChalNaTag`.

### 6.5 Timeline — 세로 예산 재설계 ★ (감사 #6, #8, #15, #4)

고정 높이를 전부 걷고 **캔버스를 유일한 가변 요소로** 둔다.

```
ChalNaNavBar               52  하한(minHeight) — Dynamic Type 시 증가
ChalNaCanvas (9:16)       가변  ← 남는 공간 전부, aspectRatio(9/16, .fit)
스크럽바                    28  고정 (캔버스에 붙임)
TransportControls           56  고정
힌트 1줄                    24  고정  ← "클립을 탭해 편집 · 길게 눌러 이동" (.caption, 1줄, 재생 중 숨김)
필름스트립                  96  고정
EditToolbar (safeAreaInset) 64  고정
─────────────────────────────
하한 합계                  320  (기본 텍스트 크기 기준)
```

SE 가용 647 → 캔버스 327pt 배정 (현재 741pt / 94pt 초과에서 여유 확보).

이 예산을 만들기 위해 지운 것과 근거:

- `labelRow`(`TIMELINE · 8 CLIPS` / `▶ NOW PLAYING · CLIP 3` + `총 1분 40초`) **삭제** — 클립 수는 필름스트립이, 총 길이는 스크럽바 `00:00 / 01:40`이, 현재 인덱스는 캔버스 우상단 `3 / 8` 배지가 이미 말한다. 같은 정보를 35pt 더 써서 두 번 말하고 있었다.
- `hintRow`만 남겨 24pt로 압축(두 행 합계 69pt → 24pt). 힌트는 발견성에 필요하므로 없애지 않는다. 재생 중에는 기존과 동일하게 숨긴다.

나머지:

- 필름스트립 UIKit 배경 `UIColor(named:"ChalNaInk") ?? .black` → `bg` 토큰. **검은 띠가 사라지고 스트립이 화면과 연속**된다.
- `DaySprocket`의 흰 점·글자 → `textSecondary`. `handFallback(13)` legacy stub → `.label`.
- `EditToolbar`: `surfaceRaised` + `lg` + `.floating`. 삭제 항목이 `Purple`(=Primary)인 것을 `destructive`로 수정.
- `TransportControls`: side 36pt(히트 44) `surface` 원, center 48pt `accentFill`.

### 6.6 ClipAdjust

구조(캔버스 `aspectRatio` fit + 양쪽 Spacer)는 이미 건전하다. **다크 전환의 최대 수혜 화면** — 러버밴드 오버슛 때 드러나는 검정 배경이 이제 화면 배경과 이어진다(현재는 흰 화면 위 검은 사각형).

- 하단 버튼 2개 → `.secondary`. 힌트 → `.caption`.
- `chalNaHeaderBar(scrollProgress: 1)`처럼 스크롤 없는 화면에 진행도 1을 억지로 주는 패턴(5곳) → `ChalNaNavBar(divider: true)`.
- 3분할 그리드 이중 스트로크(어두운 밑선 + 흰 윗선)는 밝기 무관 가시성을 위한 의도적 설계이므로 **유지**.

### 6.7 LabelEditor (감사 #2, #9)

- `sliderRowHeight = 84` 고정 예약 → 슬라이더를 `safeAreaInset(edge: .bottom)`으로 옮겨 실제 높이만 차지.
- 닫기 33pt → `ChalNaNavAction(.close)`.
- **명시적 예외:** 라벨 박스 자체(흰 배경·검은 글자)는 **영상 출력과 픽셀 일치해야 하므로 다크 토큰을 적용하지 않는다.** `ClipLabel.BoxStyle`가 SSOT이며 UI 테마와 무관하다. `inlineEditor`의 `.foregroundColor(.black)`도 이 예외에 속한다.

### 6.8 Export (감사 #7, #24)

- `GeometryReader` + `reservedHeight` 210/300/290 마법숫자 **삭제**. 커버는 `aspectRatio(9/16, .fit)`로 남는 공간을 먹고 자동 축소, CTA는 `safeAreaInset`.
- **진행률을 커버 위로 올린다.** 현재 커버와 진행 블록이 분리돼 시선이 갈린다. 커버 하단 오버레이로 합치면 "이 영상이 지금 만들어지는 중"이 한 시선에 들어온다. 별도 `statusBlock` 삭제.
- 헤더 자체 구현(`VStack{제목,태그}`) → `ChalNaNavBar(title: 단계 제목)`.
- 완료 CTA 4개(공유·저장·다른 영상·홈)가 2×2 동등 배치 → **주 2개(`저장`·`공유`) + 보조 텍스트 2개**로 위계 분리.
- 토스트 → `ChalNaToast`.

### 6.9 FilmDetail (감사 #8)

- 포스터 300 고정 → **`frame(maxWidth:)` 상한을 먼저 걸고 `aspectRatio` 적용**. 기존 주석의 "ScrollView에서 aspectRatio가 폭을 역산해 깨진다"는 진단은 정확했으나 해법이 고정값이었다. 폭을 먼저 확정하면 높이 역산이 안전하다.
- 메타 3칼럼(클립/Live/Video)이 카드 3개를 차지 — 정보량 대비 과하다. **`ChalNaTag` 3개 한 줄**로 압축하고 그 공간을 포스터에 돌려준다.
- 삭제 버튼: 손작성 커스텀 라벨 → `ChalNaButton(.ghost, destructive: true)`.

### 6.10 Settings · LabelSettings · LabelPosition · Language · Support

네 화면이 각자 행 빌더를 손으로 쓴다 → 전부 `ChalNaListRow` + `ChalNaCard`.

- **LabelPosition 3×3**: `lineWidth: 10` 버그(감사 #1) 수정 + 텍스트 라벨("좌상단"…) 대신 **9칸 미니 도형**으로 위치를 시각화. 위치 선택은 글자보다 도형이 압도적으로 빠르다.
- **Support**: 카테고리 칩 → `ChalNaTag(.accent)` 선택 상태. `TextEditor` + 수동 플레이스홀더 → `ChalNaTextArea`. 리딤 시트 다크 전환.
- **Language**: `Image(systemName: "checkmark")` 직접 사용 → `ChalNaListRow(.check)`.
- **Settings**: `cornerRadius: 8` 리터럴(감사 #14)·`.font(.system(...))` 제거.

## 7. 접근성

| 항목 | 조치 |
|---|---|
| Dynamic Type | 모든 역할 토큰에 `relativeTo:`. 앱 전역 `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` 클램프. 리스트 행은 고정 높이 대신 `minHeight`만 둬 글자가 커지면 행이 밀려 커지게 |
| 대비 | 본문 ≥4.5:1, UI 컴포넌트 ≥3:1. 측정값은 §4.1 표 |
| 터치 영역 | 44pt를 **컴포넌트가 강제**. `ChalNaNavAction`·`ChalNaListRow`·툴바 항목·제거 배지. 호출처가 줄일 수 없다 |
| VoiceOver | 현재 코드의 라벨·힌트·커스텀 액션(예: MediaPicker `accessibilityAction(named: "선택에서 제외")`)은 품질이 좋다. **전부 보존**하고 새 컴포넌트에 승계 |
| Reduce Motion | Splash 기존 대응 유지. 새 애니메이션은 `ChalNaMotion` 경유 |

### 7.1 iOS 26 `glassEffect` 분기 제거

현재 `PreviewPanel`의 HUD와 `ScrubBar`가 `#available(iOS 26.0, *)`로 glass / paper 두 경로를 각각 유지한다.
deployment target이 iOS 18이라 **양쪽을 영구히 유지해야 하는 비용**이 드는데, 얻는 것은 같은 정보의 재질 차이뿐이다.
반투명 `surfaceRaised` 하나로 통일한다.
iOS 26에서 유리 질감이 사라지는 것은 **인정하는 후퇴**이고, 대신 코드 경로가 절반이 되며 전 버전에서 동일하게 보인다.

## 8. 검증

1. **빌드** — `xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
2. **테스트** — 전체 스위트 그린 유지. 특히 `CompositorLabelTests`·`ClipFramingTests`·`CustomLabelLayoutTests`·`CompositionRenderSizeTests`는 **영상 출력 픽셀**을 지키는 방어선이다. 하나라도 깨지면 라벨/프레이밍 토큰을 잘못 건드린 신호다.
3. **시각 검증** — `ChalNa Dev` 스킴(devMock)으로 사진 권한 없이 전 플로 통과가 가능하다. 12개 화면 × 3기기:
   - iPhone SE (3rd gen) 375×667 — **세로 예산 파열 검증용**
   - iPhone 17 393×852
   - iPhone 17 Pro Max 440×956

   추가로 **SE + Dynamic Type xxxLarge** 1세트.
   Timeline 예산 계산(§6.5)은 근사치이며 **실측 스크린샷으로만 확정된다.**
4. **`DesignSystemShowcaseView`** — 토큰·컴포넌트 전수 회귀 확인. 아이콘 20종 전수 비교 포함.
5. **정적 확인** — 다음이 모두 0건:
   - `.font(.system(`
   - `Color(hex:` (토큰 정의 파일 내부 제외)
   - `cornerRadius: <숫자 리터럴>` (아이콘 패스·UIKit `visiblePath` 제외)
   - `Color.white` / `.white` (§6.7 라벨 박스 예외 명시)
   - `UIColor(named:`

## 9. 작업 순서

브랜치 하나에 순차 커밋. **중간 커밋에서도 앱이 컴파일·실행되도록** 구 토큰을 `deprecated` 심으로 남기고 마지막 단계에서 제거한다.
(이는 §2에서 배제한 "병행 도입안"과 다르다 — 그것은 두 시스템을 오래 공존시키는 것이고, 이것은 한 브랜치 안의 컴파일 유지 장치다.)

| 단계 | 내용 | 검증 |
|---|---|---|
| **P0** | 토큰 재정의(Color/Typography/Radius/Shadow/Motion) · `Info.plist` Dark · dead colorset 삭제 · 구 스케일 deprecated 표시 | 빌드 |
| **P1** | 컴포넌트 18종 + 모디파이어 2종 + `ChalNaIcon` SF Symbols 전환 + Showcase 재작성 | Showcase 스크린샷 |
| **P2** | 위험 낮은 화면: Splash · Settings · Language · Support · LabelSettings · **LabelPosition(감사 #1)** | 3기기 스크린샷 |
| **P3** | 위계 재배치: Home · MediaPicker · MediaPreviewSheet · FilmDetail · Export | 3기기 스크린샷 |
| **P4** | **최고 위험**: Timeline 세로 예산 · ClipAdjust · LabelEditor + `PreviewPanel`·`ScrubBar`·`EditToolbar`·`TransportControls`·`FilmStripCollectionView`·`DaySprocket` | SE 필수 + xxxLarge |
| **P5** | deprecated 심 삭제 · 정적 확인 5종 · **CLAUDE.md·AGENTS.md 동기화** | 전체 테스트 + 빌드 |

**단일 스펙으로 두는 근거:** P0~P5는 독립 하위 프로젝트가 아니다. 토큰 한 세트가 모든 화면을 동시에 규정하므로 쪼개면 각 조각이 다시 전체 토큰 표를 참조해야 한다. 대신 **구현 계획을 단계별로 나누고 P2·P3·P4 사이에 검토 지점을 둔다.**

CLAUDE.md 동기화는 필수다. 현재 문서가 "Danawa DDS Mobile v2.0 값", "Asset Catalog `ChalNa*.colorset`", "`.cream`/`.coral`/`.sage`" 같은 **이미 사실과 다른 내용**을 담고 있고 이번 변경으로 완전히 무효가 된다.

## 10. 비범위 (손대지 않는 것)

- **TCA 리듀서 / State / Action / delegate 네비게이션** — 순수 뷰·토큰 레이어만 변경
- **`CompositionService` · `ChalNaVideoCompositor` · `ClipFraming` · `LabelLayout` · `ClipLabel.BoxStyle`** — 영상 출력 픽셀에 영향
- `PhotosService` · `FileStorage` · `AnalyticsService`
- i18n 메커니즘(`LanguageBundle`, `Localizable.xcstrings`) — 카피는 추가·수정하되 구조는 그대로
- **`ThumbnailPreset` 12종 그라디언트 — 판단 결과 유지.** 0부터 다시 봐도 값이 이미 저채도 중간톤(`#4B6374`, `#3D5240`, `#8D7A61` …)이라 다크 배경에서 오히려 잘 맞는다. 이것은 크롬이 아니라 **콘텐츠 자리 채움**이고, 다크에서 문제가 되는 것은 채도 높은 크롬이지 사진 대역 색이 아니다. 단, Home·FilmDetail 폴백이 12종 중 6종만 쓰던 로직은 12종 전부로 넓힌다(§6.2).
- 앱 아이콘 · `splash_icon` 에셋 — 브랜드 앵커이므로 그대로 두고 토큰이 여기에 맞춘다

## 11. 리스크

| # | 리스크 | 완화 |
|---|---|---|
| 1 | **Timeline 세로 예산** — 계산상 SE에서 327pt 캔버스 확보지만 `safeAreaInset` 실제 높이와 Dynamic Type 확대가 변수 | P4에서 SE 실측 스크린샷 필수. 미달 시 필름스트립 96 → 80으로 축소하는 것이 1차 조정 레버 |
| 2 | **`FilmStripCollectionView`가 UIKit** — `UICollectionView` + `UIHostingConfiguration`이라 셀 배경·선택 하이라이트·`visiblePath`(`cornerRadius: 4` 리터럴)를 UIKit 쪽에서도 손대야 한다 | P4에서 단독 커밋으로 분리 |
| 3 | **`ChalNaIcon` SF Symbols 전환** — 호출처 41곳의 시각 무게가 한꺼번에 바뀐다 | Showcase에서 20종 전수 비교 |
| 4 | **`Color.white` 60곳** — 하나라도 놓치면 어두운 화면에 흰 판이 남는다 | P5 정적 확인이 잡는 장치 |
| 5 | Dynamic Type 상한을 열면 `ChalNaNavBar` 52pt·리스트 행 최소 높이가 압박받는다 | 행은 `minHeight`로만 두고 내용이 밀어 올리게 |
