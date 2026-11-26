import CoreGraphics

public enum FilmOutputResolution: String, CaseIterable, Sendable {
    case fourK
    case fullHD
    case hd

    public var title: String {
        switch self {
        case .fourK: "4K"
        case .fullHD: "Full HD"
        case .hd: "HD"
        }
    }

    public var width: Int {
        switch self {
        case .fourK: 2160
        case .fullHD: 1080
        case .hd: 720
        }
    }

    public var height: Int { width * 16 / 9 }

    public var renderSize: CGSize { CGSize(width: width, height: height) }
}
