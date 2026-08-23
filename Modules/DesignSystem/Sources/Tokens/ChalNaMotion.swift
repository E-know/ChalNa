import SwiftUI

/// 애니메이션 커브 토큰.
/// 근거: docs/superpowers/specs/2026-07-28-app-redesign-design.md §4.4
public enum ChalNaMotion {
    /// 상태 토글 (선택·눌림·표시/숨김).
    public static let fast: Animation = .easeOut(duration: 0.15)
    /// 레이아웃 이동 · 페이드.
    public static let standard: Animation = .easeInOut(duration: 0.24)
    /// 크롭 러버밴드 스냅백. 오버슛 없는 파라미터 — 기존 검증값을 그대로 유지한다.
    public static let spring: Animation = .spring(response: 0.35, dampingFraction: 0.85)
}
