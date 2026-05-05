# Bottom Buttons Design Review

Date: 2026-05-05

## Scope

Reviewed the bottom button areas in the current OneSecMovie iOS UI:

- MediaPicker bottom bar: `취소` / `선택 후 다음`
- Timeline bottom edit toolbar: `회전`, `자르기`, `삭제`, `음악`
- Export completion CTAs: `공유하기`, `저장하기`, `다른 영상 만들기`, `홈으로`
- Playback transport controls where they sit close to the bottom editing flow

Current screenshot saved as `current.jpg`.

## Lazyweb Status

The Lazyweb design-improve skill is installed locally and was used as the review workflow. However, the current Codex session does not expose the required Lazyweb MCP tools (`lazyweb_health`, `lazyweb_search`, `lazyweb_compare_image`, `lazyweb_find_similar`), so this review could not perform live Lazyweb screenshot search/comparison. The review therefore uses the captured simulator screen, accessibility hierarchy, and common mobile bottom-action patterns from the Lazyweb workflow.

## Findings

### 1. MediaPicker bottom buttons are not visually distributed like a bottom action bar

In `MediaPickerView.bottomBar`, both buttons apply `.frame(maxWidth: .infinity)` after `.buttonStyle(...)`, but the captured accessibility/simulator state shows the actual button frames are intrinsic-width:

- `취소`: 73.7 × 44
- `선택 후 다음`: 140.3 × 44

This keeps the hit target valid, but visually the bottom bar reads like two floating small buttons rather than a stable native bottom action row. For a selection flow, the primary action should usually be easier to scan and predict.

Suggested fix: make the label content fill before the button style, or add a full-width Moments button variant for bottom bars.

### 2. Export completion has duplicate navigation outcomes

In `ExportView.bottomCTAs`, `다른 영상 만들기` and `홈으로 →` both call `router.popToRoot()`. They sound like different actions but perform the same route. This can make users hesitate at the completion step.

Suggested fix: either remove one action, or make `다른 영상 만들기` start a new media-picking flow while `홈으로` returns to Home.

### 3. Timeline delete is safer now, but still visually equivalent to non-destructive tools

The confirmation dialog protects against accidental deletion, which is good. But the bottom toolbar still gives `삭제` the same weight/color as `회전`, `자르기`, and `음악`.

Suggested fix: keep the confirmation dialog, and consider a subtle destructive treatment for the trash icon/label or move destructive actions behind a secondary menu when the toolbar grows.

## Good Signals

- Bottom controls now have 44pt hit areas.
- Disabled MediaPicker CTA is correctly disabled in accessibility.
- Header and bottom controls have clearer accessibility labels.
- Dimmed edit toolbar is no longer interactive/focusable during playback.
- Primary coral button text now uses `ink`, avoiding the low contrast white-on-coral issue.

## Suggested Priority

1. Fix MediaPicker bottom button distribution.
2. Resolve duplicate Export completion actions.
3. Decide whether `삭제` needs a distinct destructive visual treatment.
