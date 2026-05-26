# PR preparation

# MediaPicker permission-first PhotoKit selection

## Plan

- [x] Replace system `PhotosPicker` selection with a PhotoKit-backed asset list that only shows currently authorized Live Photo/Video assets.
- [x] Request or manage photo access before showing selectable assets.
- [x] Keep Timeline preparation gated on real Live Photo paired-video or video resource extraction.
- [x] Verify the MediaPicker target and app build.
- [x] Commit the behavior change separately from unrelated generated files.

## Notes

- The previous picker-first flow could select A/B/C while limited Photos permission allowed D/E/F, which made PHAsset-based Live Photo video extraction impossible.
- The new flow should make the visible grid and PhotoKit readable asset set identical.

## Review

- Replaced system `PhotosPicker` selection with a PhotoKit-backed asset grid scoped to currently authorized or limited Photos access.
- Limited access can be expanded through the PhotoKit limited-library picker, then the grid reloads from the readable asset set.
- Selected Live Photo/Video assets resolve by `PHAsset` local identifier and still require a real video URL before Timeline.
- Verification: `MediaPickerFeature` and `OneSecMovie` builds succeeded on the iPhone 17 Pro simulator.

---

## Plan

- [x] Inspect current branch, remotes, and dirty working tree.
- [x] Stage PR-worthy source, project, fixture, and test changes while excluding local setup/noise.
- [x] Commit the prepared branch with a Korean conventional commit message.
- [x] Push the branch so a GitHub PR can be opened.
- [x] Summarize PR title/body and any remaining local unstaged files.

## Notes

- Current branch is `codex/bug/longPic`.
- Exclude `.lazyweb/`, `AGENTS.md`, generated `.swiftpm` state, local task notes, and deleted screenshot artifacts from PR staging.

## Review

- Created commit `b73e0ca` with message `✨ feat: Dev 미디어 소스 추가`.
- Pushed `codex/bug/longPic` to `origin` and set the upstream branch.
- GitHub PR URL: `https://github.com/E-know/OneSecMovie/pull/new/codex/bug/longPic`.
- Left local-only/noise files unstaged: `.lazyweb/`, `AGENTS.md`, `Tuist/.swiftpm/`, `tasks/`, and deleted screenshot artifacts.

---

# Dev Scheme media source

## Plan

- [x] Add DEBUG-only app mode detection for `CHALNA_APP_MODE=devMock`.
- [x] Add bundled dev media fixtures and a `PhotosService` source that resolves them into exportable `Clip` values.
- [x] Wire `MediaPickerView` to switch between real PhotosPicker and dev fixture selection.
- [x] Update Tuist configuration for `PhotosService` resources, tests, feature dependency, and a `OneSecMovie Dev` scheme.
- [x] Add focused Swift Testing coverage for the dev media source.
- [x] Regenerate project files and run tests/build/simulator verification.

## Notes

- Keep the real PhotoKit path behavior unchanged except for source switching.
- Dev mode is only active for DEBUG builds with `CHALNA_APP_MODE=devMock`; Release must remain real.
- Fixture media must be real mp4 files so export uses the production composition path.

## Review

- Added `OneSecMovie Dev` as a shared Tuist/Xcode scheme with `CHALNA_APP_MODE=devMock`, and gated app-mode detection so Release remains on the real Photos path.
- Added bundled mp4 fixtures plus `BundledDevMediaSource` in `PhotosService`, resolving selected dev assets into exportable `Clip` values with URL, thumbnail, duration, and display size.
- Updated `MediaPickerView` to switch between the existing PhotoKit picker and a Dev fixture grid while preserving the title, selected-count, CTA, and captured-date ordering flow.
- Fixed an export edge case discovered by the fixtures: silent videos must not create an empty composition audio track.
- Verification: `tuist generate` succeeded, `PhotosService` tests passed, `OneSecMovie-Workspace` tests passed, and simulator verification passed through Dev fixture selection, title input, Timeline playback/rotation controls, export completion, and Home showing `1 REEL` for `Dev Export`.

---

# Lazyweb Codex setup

## Plan

- [x] Write Lazyweb bearer token to local ignored config at `~/.lazyweb/lazyweb_mcp_token`.
- [x] Add Lazyweb plugin marketplace from `https://github.com/aboul3ata/lazyweb-skill`.
- [x] Ensure `[plugins."lazyweb@lazyweb"] enabled = true` exists in Codex config.
- [x] Verify Lazyweb skills and MCP tools after setup.
- [x] Run `lazyweb_health` and `lazyweb_search` with the requested pricing-page query.

## Notes

- Do not write the token into tracked repo files.
- Do not commit any setup/config changes.
- Codex restart may be required before newly installed plugin tools appear in this session.

## Review

- Token written to `~/.lazyweb/lazyweb_mcp_token` with `0600` permissions.
- Codex config now has `mcp_servers.lazyweb`, `marketplaces.lazyweb`, and `[plugins."lazyweb@lazyweb"] enabled = true`.
- The installed Codex CLI does not support `codex plugin marketplace add`; fallback was direct config plus local clone of the Lazyweb source repo into Codex plugin cache.
- MCP verification passed: `lazyweb_health` returned healthy checks and `lazyweb_search` returned pricing-page references.

---

# HIG-driven UI/UX pass

## Plan

- [x] Research current Apple Human Interface Guidelines from official sources.
- [x] Inspect the current SwiftUI screens and the Figma design for clear UI/UX gaps.
- [x] Select conservative improvements that are HIG-aligned and fit the existing ChalNa design system.
- [x] Implement the selected improvements in code.
- [x] Verify with build/tests and simulator/UI checks where possible.
- [x] Reflect the final UI/UX changes back into Figma if the file is writable.

## Notes

- Avoid broad visual redesign unless a HIG issue or usability gap is clear.
- Preserve the existing ChalNa brand direction and design-system tokens.
- Ask the user before proceeding only if the implementation choice is genuinely ambiguous or risky.
- HIG anchors: 44x44 pt minimum hit regions for buttons, visible press states, Dynamic Type for custom fonts, VoiceOver labels for key elements, determinate progress for export, grabbers/dismiss conventions for sheets, and original aspect ratio for video.
- Selected scope: Dynamic Type-friendly typography helpers, 44pt hit targets, higher contrast primary button labels, explicit VoiceOver labels, dimmed toolbar non-interactivity, delete confirmation, accessible film-strip reorder actions, sheet detents/grabber, accessible export progress.

## Review

- HIG sources reviewed: Apple Layout, Buttons, Sheets, Typography, Accessibility, VoiceOver, Progress indicators, and Playing video guidance.
- Implemented HIG-aligned code changes: scalable typography helpers, shared 44pt hit-target helper, higher-contrast button/action text, VoiceOver labels/hints, disabled dimmed toolbar, delete confirmation, accessible film-strip reorder actions, adaptive sheets, and accessible export progress.
- Verification: `OneSecMovie` simulator build passed, `TimelineFeature` tests passed 9/9, `OneSecMovie` build/run succeeded on iPhone 17 Pro simulator, and MediaPicker accessibility snapshot confirmed 44pt top/bottom controls.
- Figma was updated for contrast: `ChalNaButton` text and targeted action labels now use `ink`; final Figma audit found 0 remaining targeted white/coral action labels.

---

# Bottom button review fixes

## Plan

- [x] Confirm the reviewed code locations and router behavior.
- [x] Make MediaPicker bottom CTA buttons visually fill their row predictably.
- [x] Separate Export completion actions so `다른 영상 만들기` and `홈으로` do different things.
- [x] Give Timeline delete a subtle destructive visual treatment.
- [x] Verify with build/tests and simulator accessibility snapshots.

## Review

- `OneSecMovie` simulator build/run passed on iPhone 17 Pro.
- `TimelineFeature` tests passed 9/9.
- MediaPicker bottom buttons now report equal accessibility frames: `취소` 181x44pt and `선택 후 다음` 181x44pt.
- Export completion actions are separated: `다른 영상 만들기` clears the session and opens MediaPicker, while `홈으로` returns to Home.
- Timeline delete now uses a destructive tone and explicit accessibility hint.
- Figma reflected the destructive Timeline delete tone with the existing `color/coral` variable; MediaPicker CTA frames were already equal in the design file.

---

# MediaPicker keyboard-safe bottom actions

## Plan

- [x] Confirm why the MediaPicker bottom actions can overlap scrollable content when the keyboard is visible.
- [x] Move the bottom actions out of the `safeAreaInset` overlay path so the ScrollView always ends above them.
- [x] Verify with simulator build and keyboard-state accessibility frames.

## Review

- Removed the bottom action row from the root `safeAreaInset` overlay and placed it as a real sibling below the `ScrollView`.
- The bottom action row is now fixed vertically, so keyboard safe-area changes shrink the `ScrollView` instead of letting content sit behind the buttons.
- Verification: `OneSecMovie` simulator build/run passed. With the title field focused, bottom buttons ended at y=776 while the keyboard toolbar began at y=792, confirming the scrollable area is above the buttons.

---

# Project file cleanup

## Plan

- [x] Inspect tracked, untracked, and ignored files before deletion.
- [x] Classify safe deletion candidates using `.gitignore` and generated-cache evidence.
- [x] Delete only local generated files, OS metadata, and user-specific Xcode state.
- [x] Verify the working tree after cleanup.

## Notes

- Safe deletion scope: `.DS_Store`, ignored `xcuserdata`, ignored `WorkspaceSettings.xcsettings`, `Tuist/.build`, and local `Derived/XcodeBuild`.
- Do not delete tracked source files, Tuist manifests, `Derived/InfoPlists`, or the generated-but-tracked Xcode project because the current project references them and some already contain unrelated local changes.

## Review

- Removed local `.DS_Store` files from root, `.agents`, `.claude`, `Modules`, and `OneSecMovie` paths.
- Removed ignored Xcode/Tuist local state: `OneSecMovie.xcodeproj/xcuserdata`, `OneSecMovie.xcworkspace/xcuserdata`, `OneSecMovie.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`, `Tuist/.build`, `Tuist/.swiftpm/xcode/package.xcworkspace/xcuserdata`, and `Derived/XcodeBuild`.
- Verification: targeted `find` checks now return no matching cleanup candidates, and `git status --short --ignored` no longer lists ignored cleanup files.

---

# Custom NavigationBar Liquid Glass

## Plan

- [x] Move the shared custom header surface to native Liquid Glass on iOS 26 with material fallback for iOS 18-25.
- [x] Add DesignSystem header action button styles for standard and primary navigation actions.
- [x] Apply the styles to MediaPicker, Timeline, and Export custom NavigationBar buttons while leaving Home static header content non-interactive.
- [x] Regenerate Tuist project files and verify with build/tests where possible.

## Notes

- Preserve `chalNaHeaderBar(scrollProgress:)` signature and existing `NavigationStack` / hidden system toolbar flow.
- Do not revert existing dirty working-tree changes in `MediaPickerView.swift` or `FilmStripCollectionView.swift`.

## Review

- Shared header surface now uses iOS 26 Liquid Glass through `GlassEffectContainer` and falls back to `.ultraThinMaterial` with ChalNa cream tint on iOS 18-25.
- Added standard and primary ChalNa header action button styles, then applied them to MediaPicker, Timeline, and Export headers.
- Timeline and Export call `chalNaHeaderBar(scrollProgress: 1)` so the glass header is visible immediately.
- Fixed the flaky timeline playback test by extracting deterministic playhead advancement for direct Swift Testing coverage.
- Verification passed: `tuist generate`, `OneSecMovie` build, `OneSecMovie-Workspace` full test run, and iPhone 17 Pro simulator screenshots for Home and MediaPicker headers.
