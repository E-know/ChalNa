import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import CoreImage
import CoreImage.CIFilterBuiltins

public struct PaperGrainOverlay: View {
    public var opacity: Double
    public var tileSize: CGFloat

    public init(opacity: Double = 0.35, tileSize: CGFloat = 300) {
        self.opacity = opacity
        self.tileSize = tileSize
    }

    public var body: some View {
        GeometryReader { proxy in
            if let image = Self.grainImage(size: tileSize) {
                Image(uiImage: image)
                    .resizable(resizingMode: .tile)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blendMode(.multiply)
                    .opacity(opacity)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Grain generation (cached)

    private static var cache: [CGFloat: UIImage] = [:]

    private static func grainImage(size: CGFloat) -> UIImage? {
        if let cached = cache[size] { return cached }

        let extent = CGRect(x: 0, y: 0, width: size, height: size)
        let noise = CIFilter.randomGenerator()
        guard let noiseOut = noise.outputImage?.cropped(to: extent) else { return nil }

        // Map noise to warm ink-brown with alpha ~ noise value
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = noiseOut
        matrix.rVector = CIVector(x: 0, y: 0, z: 0, w: 0.24)
        matrix.gVector = CIVector(x: 0, y: 0, z: 0, w: 0.18)
        matrix.bVector = CIVector(x: 0, y: 0, z: 0, w: 0.14)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 0.55)
        matrix.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)

        guard let out = matrix.outputImage else { return nil }

        let context = CIContext()
        guard let cg = context.createCGImage(out, from: extent) else { return nil }
        let image = UIImage(cgImage: cg)
        cache[size] = image
        return image
    }
}

public extension View {
    /// 화면 최상위에 페이퍼 그레인을 덧씌운다.
    func paperGrain(opacity: Double = 0.35) -> some View {
        self.overlay(PaperGrainOverlay(opacity: opacity))
    }
}
