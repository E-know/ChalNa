#!/usr/bin/env bash
# 디자인 토큰 규율 정적 검사.
# 근거: docs/superpowers/specs/2026-07-28-app-redesign-design.md §8
#
# P0~P4 동안에는 실패하는 것이 정상이다(마이그레이션 진척 측정기).
# P5 에서 exit 0 이 되어야 한다.
set -uo pipefail
cd "$(dirname "$0")/.."

SCAN_DIRS=(ChalNa/Sources Modules)
FAIL=0

# $1 = 규칙 이름, $2 = grep 패턴, $3.. = 제외할 경로 조각
check() {
  local name="$1" pattern="$2"; shift 2
  local hits
  hits=$(grep -rnE "$pattern" --include='*.swift' "${SCAN_DIRS[@]}" 2>/dev/null | grep -v '/Tests/')
  # 주석 전용 줄(공백 뒤 // 또는 ///로 시작) 은 실제 코드가 아니므로 제외한다.
  # 코드 뒤에 붙은 trailing 주석은 앞쪽에 실제 코드가 있으므로 그대로 걸린다 —
  # 즉 "코드를 주석으로 감싸 규칙을 우회"하는 것과 "주석 안 프로즈가 규칙을 오탐"하는
  # 것을 동시에 해결하려면 반드시 '줄이 //로 시작하는가'만 봐야 한다.
  hits=$(printf '%s\n' "$hits" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//')
  for skip in "$@"; do
    hits=$(printf '%s\n' "$hits" | grep -v "$skip")
  done
  hits=$(printf '%s\n' "$hits" | grep -v '^$')
  local count
  count=$(printf '%s\n' "$hits" | grep -c . )
  if [ "$count" -gt 0 ]; then
    printf '\033[31m✗ %-28s %s건\033[0m\n' "$name" "$count"
    printf '%s\n' "$hits" | sed 's/^/    /'
    FAIL=1
  else
    printf '\033[32m✓ %-28s 0건\033[0m\n' "$name"
  fi
}

echo "── ChalNa design lint ──"

# 1. 시스템 폰트 직접 호출 — ChalNaIcon 은 글리프 크기 지정에 필요하므로 예외.
#    ClipLabelText·LabelEditorView 는 라벨 박스를 합성(CATextLayer)의 UIFont 측정값과
#    픽셀 일치시켜야 해서 Dynamic Type 이 붙는 역할 토큰(krBody, 삭제됨)을 쓸 수 없다.
check ".font(.system(" '\.font\(\.system\(' \
  'DesignSystem/Sources/Icons/ChalNaIcon.swift' \
  'DesignSystem/Sources/Tokens/' \
  'TimelineFeature/Sources/Components/ClipLabelText.swift' \
  'TimelineFeature/Sources/LabelEditorView.swift'

# 2. hex 리터럴 색 — 토큰 정의와 콘텐츠 그라디언트만 예외
check "Color(hex:)" 'Color\(hex:' \
  'DesignSystem/Sources/Tokens/' \
  'Models/Sources/ColorHex.swift' \
  'Models/Sources/ThumbnailPreset.swift'

# 3. cornerRadius 숫자 리터럴 — 세 가지 형태를 모두 잡는다:
#      RoundedRectangle(cornerRadius: 8)   ← 콜론형
#      layer.cornerRadius = 16             ← UIKit 대입형
#      .cornerRadius(15)                   ← SwiftUI 베어 모디파이어 (CLAUDE.md 가 명시적으로 금지)
#    'cornerRadius: [0-9]' 만 쓰면 뒤 두 형태를 영구히 못 본다.
#    ChalNaRadius.md 처럼 토큰을 넘기는 경우는 숫자가 아니라 안 걸린다.
#    구분자 앞 공백을 반드시 허용해야 한다 — `layer.cornerRadius = 16` 은
#    cornerRadius 와 '=' 사이에 공백이 있어 'cornerRadius[:=(]' 로는 안 걸린다.
# 예외: 아이콘 Path 기하(반지름이 아님)
check "cornerRadius 리터럴" 'cornerRadius *[:=(] *[0-9]' \
  'DesignSystem/Sources/Icons/ChalNaIcon.swift'

# 4. 흰색 하드코딩 — 영상 출력 픽셀과 일치해야 하는 곳만 예외
#    CompositionService: CLAUDE.md 가 "CompositionService 의 비디오 텍스트 오버레이는
#    불가피한 예외" 라고 명시하고, 스펙 §10 비범위에도 들어 있어 손댈 수 없다.
#    (UIColor.white 2곳: CompositionService.swift:488 라벨 전경, :566 배경 레이어)
#    이 예외가 없으면 규칙 4 는 Task 26 에서 결코 0 이 될 수 없다.
#    회색조 이니셜라이저 형태(Color(white:) / UIColor(white:))도 반드시 포함한다.
#    이게 빠지면 Color.white 를 Color(white: 1.0) 으로 바꾸는 것만으로 규칙을 우회할 수 있다.
#    ChalNaTag: 필 배경/보더(0.08~0.10 opacity)가 미디어·크롬 배경 어디서든 균일한
#    프로스트 톤을 의도한 컴포넌트 고유 상수라 onMedia/scrim 어느 역할과도 안 맞아 예외로 남긴다
#    (과거엔 "토큰으로 표현 불가"라고 적었으나 scrim 이 그 자체로 반증이라 근거를 고쳤다).
#    아래 8개였던 예외 중 LabelEditorView.swift·ClipLabel.swift·ThumbnailPreset.swift·
#    MediaThumb.swift 는 실제 매치가 없어(죽은 예외) 제거했다 — 죽은 예외는 그 파일에
#    새로 들어오는 진짜 위반을 영구히 가린다.
check "흰색 하드코딩" '(Color\.white|\.white\b|Color\(white:|UIColor\(white:)' \
  'DesignSystem/Sources/Tokens/' \
  'CompositionService/Sources/CompositionService.swift' \
  'TimelineFeature/Sources/Components/ClipLabelText.swift' \
  'DesignSystem/Sources/Components/ChalNaTag.swift'

# 5. 검정 하드코딩 — 규칙 4(흰색)의 대칭 규칙. Task 1 은 "값이 검정인 토큰(canvas)을
#    범용 검정으로 쓰는" 우회를 정리했는데, 그 우회가 통했던 이유가 바로 이 규칙이
#    없었기 때문이다 — 검정 하드코딩은 규칙 4처럼 아무 파일에서나 써도 5개 규칙이 전부
#    그린으로 남는다. 예외 대상은 규칙 4와 동일한 "영상 출력 픽셀 일치" 부류:
#    CompositionService(라벨 전경·테두리) · ClipLabelText(박스 자막의 검은 글자·검은 테두리가
#    CATextLayer 출력과 픽셀 일치해야 한다).
#    LabelEditorView.swift 는 라벨 2스텝 재구성에서 색 결정을 ClipLabelBoxPalette
#    (ClipLabelText.swift)로 옮기면서 검정 리터럴이 사라져 예외에서 제거했다 —
#    매치 없는 예외는 그 파일에 새로 들어오는 진짜 위반을 영구히 가린다.
#    회색조 이니셜라이저 형태(Color(white: 0)/UIColor(white: 0))도 포함 —
#    Color.black 을 Color(white: 0) 으로 바꾸는 것만으로 규칙을 우회할 수 없게 한다.
check "검정 하드코딩" '(Color\.black|\.black\b|Color\(white: *0(\b|\.)|UIColor\.black|UIColor\(white: *0(\b|\.))' \
  'DesignSystem/Sources/Tokens/' \
  'CompositionService/Sources/CompositionService.swift' \
  'TimelineFeature/Sources/Components/ClipLabelText.swift'

# 6. UIColor(named:) — 번들 조회가 조용히 실패하는 패턴
check "UIColor(named:)" 'UIColor\(named:'

echo "────────────────────────"
if [ "$FAIL" -eq 0 ]; then
  echo -e "\033[32m전부 통과\033[0m"
else
  echo -e "\033[33m위반 남음 (P5 까지 정상)\033[0m"
fi
exit "$FAIL"
