# 세로 고정 센터 크롭 + 러버밴드 크롭 조정 + 편집 UX 개선 — 설계

날짜: 2026-07-13 · 브랜치: `feature/portrait-crop-framing`

## Goal

1. 출력은 무조건 세로(9:16). 가로 소스는 **기본 센터 크롭(aspect-fill)**, 사용자가 드래그로 크롭 영역을 조정할 수 있다. 배경 블러는 제거한다.
2. 크롭 드래그가 한계에 닿으면 **러버밴드(저항) + 스프링백 바운스**로 한계 도달을 체감시킨다.
3. 인터넷 심층 리서치로 수립한 UX 목표를 편집 플로우에 반영한다.

## 현재 구조 (조사 결과)

- 출력 캔버스는 이미 1080×1920 고정(`CompositionService.outputSize`). 문제는 전경 기본 배치가 **aspectFit(레터박스)** 이고, 여백을 같은 프레임의 aspectFill+가우시안 블러(σ≈43px)+검정 스크림 18%로 채우는 것(`ChalNaVideoCompositor`).
- 기하 SSOT는 `ClipFraming`(Models) — 프리뷰(`PreviewPanel`)·조정(`ClipAdjustView`)·합성(export)이 공유(WYSIWYG).
- 사용자 조정값은 `ClipTransform(scale, offset)` → `EditSession.transforms`. offset 은 `ClipFraming.clampedOffset` 하드 클램프(바운스 없음).
- 블러 배경이 3곳 중복: 컴포지터(export), `ClipAdjustView`(blur 18), `PreviewPanel`(blur 14).
- 라벨 앵커가 "클립 fit 사각형(placedRect, 줌 미반영)" 기준 — 줌/팬 시 자막 위치가 실제 보이는 것과 어긋나는 잠재 결함.

## UX 리서치 결과 → UX 목표

리서치(CapCut·InShot·Apple Photos·Memories·Google Photos·NN/g·HIG·IMG.LY, 출처는 워크플로우 기록):

- 가로→세로 변환의 업계 공통 기본값 = **aspect-fill 센터 크롭** + 드래그 리프레이밍(해상도 보존형, 하드 크롭 아님).
- 러버밴드 공식(UIScrollView, c=0.55): `b = (1 − 1/((x·c/d) + 1))·d`. 스냅백은 오버슛 없는 스프링(`response 0.3~0.35, dampingFraction ≥0.8`).
- 한계 도달 햅틱은 Bool 상태-diff 로 1회만(스팸 금지), `.rigid` 임팩트.
- 3분할 그리드는 **드래그 중에만** 표시(Apple Photos 패턴). 더블탭 = 기본 프레이밍 리셋(모바일 표준 규약).

이 앱의 편집 UX 목표:

| # | 목표 | 이번 반영 |
|---|---|---|
| U1 | 무조작 안전 기본값 — 가로 소스도 자동 센터 크롭으로 "완성 상태" | fill 기본값 (Goal 1) |
| U2 | 직접 조작 + 즉각(0.1s) 피드백 — 조작 결과가 프리뷰에 바로 보임 | 러버밴드·그리드·햅틱 (Goal 2) |
| U3 | 가역성 — 실수해도 안전 | 더블탭 리셋 + 초기화 버튼 |
| U4 | 상태 가시성 — 조정됨 표시, 한계 도달 표시 | 러버밴드 + 햅틱 + 툴바 dot(기존) |
| U5 | 표준 제스처만, 버튼 대안 병행(HIG) | 핀치/드래그/더블탭 + 초기화 버튼 |
| U6 | WYSIWYG — 프리뷰=조정=출력 픽셀 일치 | ClipFraming SSOT 유지·강화 |

## 설계 결정

### A. 기하: fit 기반 → fill 기반 (Goal 1)

- `ClipFraming.fillScale(display:rotation:render:)` 추가(max 기반, fitScale 의 쌍둥이). `clampedOffset`·`resolvedRect` 의 기준 배율을 fillScale 로 교체 → 프리뷰·조정·export 가 한 번에 센터 크롭으로 전환.
- `ClipTransform.scale` 의미 재정의: **fill 대비 배율**. 하한 1.0(캔버스를 항상 덮음 → 여백/블러 원천 불가), 상한 4.0. 기본 정적 상수 `.fit` → `.fill` 로 rename.
- `ClipFraming.maxOffsetFraction(display:rotation:render:scale:)` 공개 — 한계 검출(러버밴드·햅틱)용.
- `CompositionService.transform()` 기준 배율 fill 로 교체, userScale 하한 `max(1.0, …)`.
- **블러 경로 전면 제거**: `fillTransform()` 삭제, `ChalNaCompositionInstruction` 의 background/blurRadius/scrimAlpha 필드 삭제, 컴포지터는 검정 배경 위 전경+라벨만 합성. 프리뷰 2곳의 블러 배경도 제거.
- 라벨 앵커 단순화: fill 에서는 보이는 클립 영역 = 캔버스 전체이므로 `placedRect` = 캔버스 rect. `LabelBoxGeometry.displayAspect`(클립 비율 박스) 사용처는 9:16 캔버스 박스로 통일 — LabelEditor·PreviewPanel·export 의 라벨 좌표계가 전부 캔버스 기준으로 일치(기존 어긋남 결함도 해소).
- `LabelEditorView` 캔버스는 9:16 박스 + `ClipFraming.resolvedRect` 로 클립 배치(조정 결과 반영 WYSIWYG).

### B. 러버밴드 + 스프링백 (Goal 2)

- Models 에 `RubberBand` 순수 함수 추가: `displacement(excess:dimension:coefficient: 0.55)` = `(1 − 1/((x·c/d) + 1))·d`, 1D 편의 함수 `value(proposed:min:max:dimension:)`. 정규화 offset 공간에서 dimension=1 로 사용(포인트 공간 공식과 동치).
- `ClipAdjustView`:
  - 드래그 중: raw 누적값을 유지하고 표시 offset 은 한계 초과분을 러버밴드로 감쇠(축별). 핀치도 [1, 4] 초과분을 동일하게 감쇠.
  - 드래그 종료: `withAnimation(.spring(response: 0.35, dampingFraction: 0.85))` 로 클램프 값에 스냅백 후 `EditSession` 커밋(커밋 값은 항상 클램프).
  - 한계 도달 순간 1회 `.rigid` 햅틱(Bool 상태-diff).
  - 드래그 중에만 3분할 그리드 페이드인/아웃.
  - 더블탭 = `.fill`(센터 크롭) 리셋.

### C. UX 개선 (Goal 3)

- 조정 화면 힌트/컨트롤 문구를 크롭 의미론으로 갱신("드래그로 보이는 부분 이동 · 핀치 확대 · 더블탭 초기화").
- U1~U6 은 A·B 로 대부분 충족. 프리뷰-출력 불일치(블러 근사 상수 상이)도 블러 제거로 해소.

### 스코프 제외 (YAGNI)

- 배경 블러 필 옵션(fit 모드 토글), 앵커 핀치 줌(손가락 위치 기준), dimmed 오버플로 표시(fill 특성상 화면 밖이라 실익 낮음), undo 스택, 필름스트립 UX 재설계.

## 영향 파일

- Models: `ClipFraming.swift`, `ClipTransform.swift`, `RubberBand.swift`(신규)
- CompositionService: `CompositionService.swift`, `ChalNaVideoCompositor.swift`
- AppCore: `EditSession.swift`(`.fit`→`.fill` 참조)
- TimelineFeature: `ClipAdjustView.swift`, `PreviewPanel.swift`, `LabelEditorView.swift`, `LabelBoxGeometry.swift`, `TimelineView.swift`(dot 조건)
- Tests: `ClipFramingTests`, `CompositionTransformTests`, `CompositorRenderTests`, `CompositorOrientationTests`, `CompositionRenderSizeTests`, `EditSessionScalesTests` 갱신 + `RubberBandTests`(신규)

## 검증 계획

1. 순수 수학 단위 테스트: fill 배율·offset 한계·러버밴드 공식(경계·단조·점근 캡).
2. 픽셀 E2E: 4분면 가로 영상 → 센터 크롭 확인(상하 블러바 없음, 4분면 위치 정확), offset 반영 크롭 확인.
3. `xcodebuild test` 전체 통과.
4. `ChalNa Dev` 스킴 시뮬레이터 실행(ios-build-run) → 조정 화면 드래그 바운스·그리드·더블탭 시각 확인, export 결과물 확인.
