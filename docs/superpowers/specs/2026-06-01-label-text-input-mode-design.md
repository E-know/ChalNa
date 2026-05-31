# 라벨 텍스트 입력 — 인플레이스 포커스 모드 (A1) 설계 스펙

- 날짜: 2026-06-01
- 브랜치: `feature/commentLabel`
- 상태: 설계 확정(사용자 승인) → 구현

## 1. 배경 / 문제

클립별 라벨 기능에서 `LabelEditorView` 하단의 인라인 `ChalNaTextField`로 텍스트를 입력하는데, 키보드가 올라오면 SwiftUI 기본 키보드 회피로 캔버스(사진/Live Photo)가 리스케일되어 작아지고, 입력칸이 답답하다. (Task 15에서 `.ignoresSafeArea(.keyboard)`로 사진 축소는 막았으나, 타이핑 중 컨트롤이 키보드에 가려지는 한계가 남음.)

## 2. 목표

텍스트 **입력**을 별도의 포커스 화면(`LabelTextInputView`, 인스타 스토리 방식)으로 분리한다. 편집 화면(`LabelEditorView`)에는 텍스트필드를 두지 않아 키보드가 뜨지 않게 하고, 스타일(폰트/글자색/배경/크기)과 위치 드래그만 담당한다.

## 3. 컴포넌트

### 3.1 `LabelTextInputView` (신규) — `Modules/TimelineFeature/Sources/LabelTextInputView.swift`
전체화면 포커스 텍스트 입력 모드.
- 배경: 클립 사진을 어둡게 딤(예: 검정 0.5 불투명)으로 깔아 맥락 유지.
- 중앙: 단일 행 텍스트를 **크게 가운데 정렬**, 커서 표시. 라벨의 **선택된 폰트**(`.memoment`/`.system`)로 렌더(폰트 WYSIWYG). 가독성 위해 입력 중 글자색은 **흰색 고정**(최종 색/배경/크기/위치는 편집 화면에서).
- 상단바: `취소` / `완료`.
- 진입 시 `@FocusState`로 키보드 자동 포커스. 단일 행(`onSubmit` 또는 `완료`로 종료).
- 구현: 큰 폰트 + `.multilineTextAlignment(.center)` + 흰색 + 포커스된 `TextField`(라벨 폰트 적용)를 딤 사진 위에 배치. (커스텀 폰트는 `ChalNaTypography.memoment`/`krBody` 사용.)
- 입력/콜백: `init(initialText:font:onCommit:onCancel:)`. 로컬 `@State text`(초기값 `initialText`). `완료` → `onCommit(text)`. `취소` → `onCancel()`(변경 폐기).

### 3.2 `LabelEditorView` (수정)
- `controls`에서 `ChalNaTextField` **제거**. 컨트롤 = 폰트 · 글자색 · 배경 · 크기.
- Task 15의 키보드 우회(`import UIKit`, `.ignoresSafeArea(.keyboard, edges: .bottom)`, 캔버스 탭→`dismissKeyboard()`, `dismissKeyboard()` 헬퍼) **제거**(편집 화면에 키보드가 안 뜸).
- 입력 모드 표시 상태: `@State private var isEditingText: Bool`.
- **라벨 탭 → 입력 모드**: 캔버스의 라벨(placeholder 포함)에 `.onTapGesture { isEditingText = true }` 추가. 기존 위치 이동 `DragGesture`와 공존(탭=편집, 드래그=이동).
- **빈 라벨 자동 진입**: `.onAppear` 에서 `label.isVisible == false` 이면 `isEditingText = true`.
- **표시**: `.fullScreenCover(isPresented: $isEditingText)` 로 `LabelTextInputView(initialText: label.text, font: label.font, onCommit: { label.text = $0; isEditingText = false }, onCancel: { isEditingText = false })`.

## 4. 진입/종료 흐름

1. 편집 화면 열림 → 라벨이 비어 있으면 입력 모드 자동 표시. 있으면 편집 화면.
2. 입력 모드: 타이핑 → `완료` → 텍스트 반영, 편집 화면 복귀(위치/스타일 조정). `취소` → 변경 폐기.
3. 편집 화면에서 라벨 탭 → 입력 모드 재진입. 드래그 → 위치 이동.
4. 편집 화면 `저장` → `ClipLabel`을 `EditSession`에 커밋(기존과 동일).

## 5. 데이터 흐름
입력 모드는 텍스트만 편집(로컬 `@State`), `onCommit`으로 편집 화면의 `label.text` 갱신. 폰트/글자색/배경/크기/위치는 편집 화면 소관. 단일 진실 공급원은 편집 화면의 `@State label: ClipLabel`.

## 6. 변경/신규 파일
- 신규: `Modules/TimelineFeature/Sources/LabelTextInputView.swift`
- 수정: `Modules/TimelineFeature/Sources/LabelEditorView.swift`

## 7. 검증 기준
1. `ChalNa` 빌드 성공, 기존 단위 테스트 유지(AppCore 11 + CompositionService 22).
2. devMock: 빈 라벨 클립 → 에디터 진입 시 입력 모드 자동 표시 → 타이핑 → 완료 → 편집 화면 라벨 반영.
3. 기존 라벨 클립 → 에디터에서 라벨 탭 → 입력 모드 재진입/수정. 드래그로 위치 이동(탭과 구분).
4. 편집 화면에 텍스트필드 없음 → 키보드로 인한 사진 축소 없음.
5. 입력 모드: 폰트 WYSIWYG, 흰색 글자, 취소/완료 동작.

## 8. 비범위
- 입력 모드에서 스타일(색/배경/크기) 조정(A2) — 제외(편집 화면 담당).
- 멀티라인 라벨 — 단일 행 유지.
- 입력 중 최종 색/배경 그대로 미리보기 — v1 제외(흰색 고정).

## 9. 리스크
- 탭 vs 드래그 제스처 공존: `DragGesture(minimumDistance:)` 기본값으로 짧은 탭은 `onTapGesture`, 이동은 드래그로 분기. 충돌 시 `simultaneousGesture`/`highPriorityGesture` 또는 `exclusively` 로 조정.
- `.fullScreenCover` 안의 `TextField` 자동 포커스: `@FocusState` 를 `.onAppear`(또는 `.task`)에서 true 로. iOS에서 cover 표시 직후 포커스가 안 잡히면 약간의 지연 후 설정.
- 커스텀 폰트(MemomentKkukkukk) 큰 크기 렌더 — 기존 `ChalNaTypography.memoment` 사용(실패 시 시스템 fallback).
