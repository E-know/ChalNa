# Lessons

- UIKit-backed SwiftUI bridges must be verified against the current working tree before claiming a fix. If a `UICollectionViewDiffableDataSource` snapshot keeps the same item identifiers, selection-only visual state changes need an explicit visible-cell refresh or a local UIKit state update, not only model-level tests.
- Before reporting a UI gating fix as done, confirm the actual working tree contains the gating change and that the action path rechecks the same predicate. For MediaPicker-style flows, selection count is not a valid readiness signal; use explicit per-item loading completion and required payload availability.
- When moving a timeline HUD element out of an image overlay, preserve its visibility contract explicitly. If the user asks for a new position, confirm whether the control should always exist there in idle and playing states, not only during playback.
- Do not treat Live Photo motion as an optional fallback when relaxing Photos permission timing. The picker may open without preauthorization, but selected Live Photos must still request the permission needed for paired-video extraction and must not proceed as still clips.
