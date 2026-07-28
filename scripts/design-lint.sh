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

# 3. cornerRadius 숫자 리터럴 — 아이콘 패스·UIKit visiblePath 는 예외
check "cornerRadius 리터럴" 'cornerRadius: [0-9]' \
  'DesignSystem/Sources/Icons/ChalNaIcon.swift' \
  'FilmStripCollectionView.swift'

# 4. 흰색 하드코딩 — 라벨 박스(영상 출력 픽셀 일치)만 예외
check "흰색 하드코딩" '(Color\.white|\.white\b)' \
  'DesignSystem/Sources/Tokens/' \
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
