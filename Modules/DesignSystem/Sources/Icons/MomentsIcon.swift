import SwiftUI

public enum MomentsIconKind: String, CaseIterable, Sendable {
    case play, pause, plus, share, download, heart, calendar, film
    case chevronLeft, chevronRight, close, check
    case skipBack, skipForward
    case scissors, reorderLines, trash, music
    case move
    case rotate
}

/// Lucide 스타일 라인 아이콘. 1.5pt stroke, 24x24 viewBox, round cap/join.
public struct MomentsIcon: View {
    public let kind: MomentsIconKind
    public var size: CGFloat
    public var strokeWidth: CGFloat

    public init(_ kind: MomentsIconKind, size: CGFloat = 24, strokeWidth: CGFloat = 1.5) {
        self.kind = kind
        self.size = size
        self.strokeWidth = strokeWidth
    }

    public var body: some View {
        if kind == .rotate {
            Image(systemName: "rotate.left")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.monochrome)
                .frame(width: size, height: size)
        } else {
            LucideShape(kind: kind)
                .stroke(style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Shape

private struct LucideShape: Shape {
    let kind: MomentsIconKind

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let tx = rect.minX + (rect.width  - 24 * scale) / 2
        let ty = rect.minY + (rect.height - 24 * scale) / 2

        var p = Path()
        let base = subpaths(for: kind)
        for sub in base {
            p.addPath(sub, transform: CGAffineTransform(scaleX: scale, y: scale)
                        .concatenating(CGAffineTransform(translationX: tx, y: ty)))
        }
        return p
    }

    private func subpaths(for kind: MomentsIconKind) -> [Path] {
        switch kind {
        case .play:
            return [Path { p in
                p.move(to: CGPoint(x: 5, y: 3))
                p.addLine(to: CGPoint(x: 19, y: 12))
                p.addLine(to: CGPoint(x: 5, y: 21))
                p.closeSubpath()
            }]

        case .pause:
            return [
                Path(CGRect(x: 6, y: 4, width: 4, height: 16)),
                Path(CGRect(x: 14, y: 4, width: 4, height: 16))
            ]

        case .plus:
            return [
                segment(12, 5, 12, 19),
                segment(5, 12, 19, 12)
            ]

        case .share:
            return [
                Path(ellipseIn: CGRect(x: 15, y: 2,  width: 6, height: 6)),
                Path(ellipseIn: CGRect(x: 3,  y: 9,  width: 6, height: 6)),
                Path(ellipseIn: CGRect(x: 15, y: 16, width: 6, height: 6)),
                segment(8.59, 13.51, 15.42, 17.49),
                segment(15.41, 6.51, 8.59, 10.49)
            ]

        case .download:
            return [
                Path { p in
                    p.move(to: .init(x: 21, y: 15))
                    p.addLine(to: .init(x: 21, y: 19))
                    p.addQuadCurve(to: .init(x: 19, y: 21), control: .init(x: 21, y: 21))
                    p.addLine(to: .init(x: 5, y: 21))
                    p.addQuadCurve(to: .init(x: 3, y: 19), control: .init(x: 3, y: 21))
                    p.addLine(to: .init(x: 3, y: 15))
                },
                Path { p in
                    p.move(to: .init(x: 7, y: 10))
                    p.addLine(to: .init(x: 12, y: 15))
                    p.addLine(to: .init(x: 17, y: 10))
                },
                segment(12, 15, 12, 3)
            ]

        case .heart:
            return [Path { p in
                p.move(to: .init(x: 12, y: 21.23))
                p.addLine(to: .init(x: 4.22, y: 13.45))
                p.addLine(to: .init(x: 3.16, y: 12.39))
                p.addCurve(to: .init(x: 10.94, y: 4.61),
                           control1: .init(x: 1, y: 10.23),
                           control2: .init(x: 5, y: 2.5))
                p.addLine(to: .init(x: 12, y: 5.67))
                p.addLine(to: .init(x: 13.06, y: 4.61))
                p.addCurve(to: .init(x: 20.84, y: 12.39),
                           control1: .init(x: 19, y: 2.5),
                           control2: .init(x: 23, y: 10.23))
                p.addLine(to: .init(x: 19.78, y: 13.45))
                p.closeSubpath()
            }]

        case .calendar:
            return [
                Path(roundedRect: CGRect(x: 3, y: 4, width: 18, height: 18), cornerRadius: 2),
                segment(16, 2, 16, 6),
                segment(8, 2, 8, 6),
                segment(3, 10, 21, 10)
            ]

        case .film:
            return [
                Path(roundedRect: CGRect(x: 2, y: 2, width: 20, height: 20), cornerRadius: 2),
                segment(7, 2, 7, 22),
                segment(17, 2, 17, 22),
                segment(2, 12, 22, 12),
                segment(2, 7, 7, 7),
                segment(2, 17, 7, 17),
                segment(17, 17, 22, 17),
                segment(17, 7, 22, 7)
            ]

        case .chevronLeft:
            return [
                segment(15, 18, 9, 12),
                segment(9, 12, 15, 6)
            ]

        case .chevronRight:
            return [
                segment(9, 6, 15, 12),
                segment(15, 12, 9, 18)
            ]

        case .close:
            return [
                segment(18, 6, 6, 18),
                segment(6, 6, 18, 18)
            ]

        case .check:
            return [
                segment(20, 6, 9, 17),
                segment(9, 17, 4, 12)
            ]

        case .skipBack:
            return [
                Path { p in
                    p.move(to: .init(x: 19, y: 20))
                    p.addLine(to: .init(x: 9, y: 12))
                    p.addLine(to: .init(x: 19, y: 4))
                    p.closeSubpath()
                },
                segment(5, 19, 5, 5)
            ]

        case .skipForward:
            return [
                Path { p in
                    p.move(to: .init(x: 5, y: 4))
                    p.addLine(to: .init(x: 15, y: 12))
                    p.addLine(to: .init(x: 5, y: 20))
                    p.closeSubpath()
                },
                segment(19, 5, 19, 19)
            ]

        case .scissors:
            return [
                segment(6, 3, 6, 21),
                segment(3, 6, 21, 6),
                segment(13, 13, 18, 18)
            ]

        case .reorderLines:
            return [
                segment(8, 6, 21, 6),
                segment(8, 12, 21, 12),
                segment(8, 18, 21, 18),
                Path(ellipseIn: CGRect(x: 2.3, y: 4.8, width: 2.4, height: 2.4)),
                Path(ellipseIn: CGRect(x: 2.3, y: 10.8, width: 2.4, height: 2.4)),
                Path(ellipseIn: CGRect(x: 2.3, y: 16.8, width: 2.4, height: 2.4))
            ]

        case .trash:
            return [
                segment(3, 6, 21, 6),
                Path { p in
                    p.move(to: .init(x: 8, y: 6))
                    p.addLine(to: .init(x: 8, y: 4))
                    p.addQuadCurve(to: .init(x: 10, y: 2), control: .init(x: 8, y: 2))
                    p.addLine(to: .init(x: 14, y: 2))
                    p.addQuadCurve(to: .init(x: 16, y: 4), control: .init(x: 16, y: 2))
                    p.addLine(to: .init(x: 16, y: 6))
                },
                Path { p in
                    p.move(to: .init(x: 19, y: 6))
                    p.addLine(to: .init(x: 19, y: 20))
                    p.addQuadCurve(to: .init(x: 17, y: 22), control: .init(x: 19, y: 22))
                    p.addLine(to: .init(x: 7, y: 22))
                    p.addQuadCurve(to: .init(x: 5, y: 20), control: .init(x: 5, y: 22))
                    p.addLine(to: .init(x: 5, y: 6))
                }
            ]

        case .music:
            return [
                Path { p in
                    p.move(to: .init(x: 9, y: 18))
                    p.addLine(to: .init(x: 9, y: 5))
                    p.addLine(to: .init(x: 21, y: 3))
                    p.addLine(to: .init(x: 21, y: 16))
                },
                Path(ellipseIn: CGRect(x: 3, y: 15, width: 6, height: 6)),
                Path(ellipseIn: CGRect(x: 15, y: 13, width: 6, height: 6))
            ]

        case .move:
            return [
                Path { p in
                    p.move(to: .init(x: 9, y: 3))
                    p.addLine(to: .init(x: 5, y: 3))
                    p.addQuadCurve(to: .init(x: 3, y: 5), control: .init(x: 3, y: 3))
                    p.addLine(to: .init(x: 3, y: 9))
                },
                Path { p in
                    p.move(to: .init(x: 15, y: 3))
                    p.addLine(to: .init(x: 19, y: 3))
                    p.addQuadCurve(to: .init(x: 21, y: 5), control: .init(x: 21, y: 3))
                    p.addLine(to: .init(x: 21, y: 9))
                },
                Path { p in
                    p.move(to: .init(x: 9, y: 21))
                    p.addLine(to: .init(x: 5, y: 21))
                    p.addQuadCurve(to: .init(x: 3, y: 19), control: .init(x: 3, y: 21))
                    p.addLine(to: .init(x: 3, y: 15))
                },
                Path { p in
                    p.move(to: .init(x: 15, y: 21))
                    p.addLine(to: .init(x: 19, y: 21))
                    p.addQuadCurve(to: .init(x: 21, y: 19), control: .init(x: 21, y: 21))
                    p.addLine(to: .init(x: 21, y: 15))
                },
                Path(ellipseIn: CGRect(x: 9, y: 9, width: 6, height: 6))
            ]

        case .rotate:
            return []
        }
    }

    private func segment(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x2, y: y2))
        }
    }
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 24) {
        ForEach(MomentsIconKind.allCases, id: \.self) { kind in
            VStack(spacing: 8) {
                MomentsIcon(kind, size: 28)
                    .foregroundColor(MomentsColor.ink)
                Text(kind.rawValue)
                    .font(MomentsTypography.monoFallback(10, weight: .medium))
                    .tracking(1)
                    .foregroundColor(MomentsColor.taupe)
            }
        }
    }
    .padding(32)
    .background(MomentsColor.cream)
}
