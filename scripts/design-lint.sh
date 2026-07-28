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

# 1. 시스템 폰트 직접 호출 — ChalNaIcon 은 글리프 크기 지정에 필요하므로 예외
check ".font(.system(" '\.font\(\.system\(' \
  'DesignSystem/Sources/Icons/ChalNaIcon.swift' \
  'DesignSystem/Sources/Tokens/'

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
# 예외: 아이콘 Path 기하(반지름이 아님), FilmStripCollectionView(Task 21 이 토큰화하며 이 예외를 제거)
check "cornerRadius 리터럴" 'cornerRadius *[:=(] *[0-9]' \
  'DesignSystem/Sources/Icons/ChalNaIcon.swift' \
  'FilmStripCollectionView.swift'

# 4. 흰색 하드코딩 — 영상 출력 픽셀과 일치해야 하는 곳만 예외
#    CompositionService: CLAUDE.md 가 "CompositionService 의 비디오 텍스트 오버레이는
#    불가피한 예외" 라고 명시하고, 스펙 §10 비범위에도 들어 있어 손댈 수 없다.
#    (UIColor.white 2곳: CompositionService.swift:488 라벨 전경, :566 배경 레이어)
#    이 예외가 없으면 규칙 4 는 Task 26 에서 결코 0 이 될 수 없다.
check "흰색 하드코딩" '(Color\.white|\.white\b)' \
  'DesignSystem/Sources/Tokens/' \
  'CompositionService/Sources/CompositionService.swift' \
  'TimelineFeature/Sources/Components/ClipLabelText.swift' \
  'TimelineFeature/Sources/LabelEditorView.swift' \
  'Models/Sources/ClipLabel.swift' \
  'Models/Sources/ThumbnailPreset.swift'

# 5. UIColor(named:) — 번들 조회가 조용히 실패하는 패턴
check "UIColor(named:)" 'UIColor\(named:'

echo "────────────────────────"
if [ "$FAIL" -eq 0 ]; then
  echo -e "\033[32m전부 통과\033[0m"
else
  echo -e "\033[33m위반 남음 (P5 까지 정상)\033[0m"
fi
exit "$FAIL"
