import SwiftUI

public extension View {
    /// Expands compact custom controls to the HIG-recommended minimum hit area
    /// without requiring every call site to know the exact platform size.
    func momentsHitTarget(
        minSize: CGFloat = MomentsSpacing.minimumHitTarget
    ) -> some View {
        self
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
}
