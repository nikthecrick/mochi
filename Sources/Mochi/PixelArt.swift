import Foundation
import CoreGraphics
import ImageIO
import AppKit

// Shared CoreGraphics renderer for the pixel sprites (app icon, death-note PNG).

enum PixelArt {
    /// Draws a sprite frame into a CGContext. `cell` = size of one sprite pixel.
    /// Sprite row 0 is the top row; CG origin is bottom-left, so rows are flipped.
    /// `tint` overrides the palette (used for the icon drop shadow pass).
    static func draw(_ frame: Frame, in ctx: CGContext, cell: CGFloat,
                     originX: CGFloat = 0, originY: CGFloat = 0, tint: CGColor? = nil) {
        let g = Sprites.grid(frame)
        let n = SpriteGrid.size
        for y in 0..<n {
            for x in 0..<n {
                let ch = g.at(x, y)
                guard ch != "." else { continue }
                ctx.setFillColor(tint ?? Pal.cgColor(ch))
                let px = originX + CGFloat(x) * cell
                let py = originY + CGFloat((n - 1 - y)) * cell
                ctx.fill(CGRect(x: px, y: py, width: cell, height: cell))
            }
        }
    }

    /// Nearest-neighbour PNG of one sprite frame (e.g. tombstone for the death note).
    static func pngData(frame: Frame, pixels: Int, background: CGColor? = nil) -> Data? {
        let n = SpriteGrid.size
        guard let small = CGContext(
            data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        if let background = background {
            small.setFillColor(background)
            small.fill(CGRect(x: 0, y: 0, width: n, height: n))
        }
        draw(frame, in: small, cell: 1)
        guard let smallImage = small.makeImage() else { return nil }

        guard let big = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        if let background = background {
            big.setFillColor(background)
            big.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        }
        big.interpolationQuality = .none
        big.draw(smallImage, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        guard let image = big.makeImage() else { return nil }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}

// Retro (pixel pet + CRT scanlines) x modern (soft gradient, rounded corners, shadow).
enum IconMaker {
    static func pngData(size: Int) -> Data? {
        let s = CGFloat(size)
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        let radius = s * 0.225
        let path = CGPath(
            roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
            cornerWidth: radius, cornerHeight: radius, transform: nil)

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()

        // modern pastel gradient
        let grad = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            colors: [Pal.cgColor("B"), Pal.cgColor("P")] as CFArray,
            locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: s, y: s), options: [])

        // retro sprite shadow + sprite
        let cell = s / 16 * 0.9
        let margin = (s - 16 * cell) / 2
        PixelArt.draw(.idleA, in: ctx, cell: cell,
                      originX: margin + cell * 0.7, originY: margin - cell * 0.7,
                      tint: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.28))
        PixelArt.draw(.idleA, in: ctx, cell: cell, originX: margin, originY: margin)

        // subtle CRT scanlines
        let lines = 26
        ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.05))
        var i = 0
        while i < lines {
            let yy = CGFloat(i) / CGFloat(lines) * s
            let hh = s / CGFloat(lines) / 2
            ctx.fill(CGRect(x: 0, y: yy, width: s, height: hh))
            i += 2
        }
        ctx.restoreGState()

        // modern hairline border
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.35))
        ctx.setLineWidth(max(1, s * 0.012))
        ctx.addPath(path)
        ctx.strokePath()

        guard let image = ctx.makeImage() else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}