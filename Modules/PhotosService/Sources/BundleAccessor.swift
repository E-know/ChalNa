import Foundation

private final class BundleToken {}

extension Foundation.Bundle {
    static let module: Bundle = Bundle(for: BundleToken.self)
}
