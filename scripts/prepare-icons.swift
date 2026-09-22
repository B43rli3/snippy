import AppKit

/// Baut das App-Icon und das Menüleisten-Icon.
/// Der weiße Rand um das Symbol wird entfernt und das Motiv auf die volle Fläche gezogen.

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let appSource = URL(fileURLWithPath: CommandLine.arguments[2])
let menuSource = URL(fileURLWithPath: CommandLine.arguments[3])

let iconset = root.appendingPathComponent("Snippy/AppIcon.iconset")
let appIconSet = root.appendingPathComponent("Snippy/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let appImage = knockOutNearWhite(NSImage(contentsOf: appSource)!)
let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]
for (name, pixels) in sizes {
    let rendered = render(appImage, pixels: pixels)
    try pngData(rendered).write(to: iconset.appendingPathComponent(name))
}

let catalogMap: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]
for (name, _) in catalogMap {
    let data = try Data(contentsOf: iconset.appendingPathComponent(name))
    try data.write(to: appIconSet.appendingPathComponent(name))
}

let menu = templateMenuIcon(NSImage(contentsOf: menuSource)!)
try pngData(menu).write(to: root.appendingPathComponent("Snippy/MenuIcon.png"))
print("icons ready")

func knockOutNearWhite(_ image: NSImage) -> NSImage {
    let side = 1024
    let rep = bitmap(image, width: side, height: side)
    mutate(rep) { pixels, width, height in
        func isOuterWhite(_ offset: Int) -> Bool {
            let alpha = Int(pixels[offset + 3])
            if alpha < 8 { return true }
            let r = Int(pixels[offset])
            let g = Int(pixels[offset + 1])
            let b = Int(pixels[offset + 2])
            let maxChannel = max(r, max(g, b))
            let minChannel = min(r, min(g, b))
            return maxChannel > 236 && (maxChannel - minChannel) < 16
        }

        var seen = [Bool](repeating: false, count: width * height)
        var stack: [Int] = []
        func push(_ x: Int, _ y: Int) {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            let index = y * width + x
            if seen[index] { return }
            let offset = index * 4
            guard isOuterWhite(offset) else { return }
            seen[index] = true
            pixels[offset + 3] = 0
            stack.append(index)
        }
        for x in 0..<width {
            push(x, 0)
            push(x, height - 1)
        }
        for y in 0..<height {
            push(0, y)
            push(width - 1, y)
        }
        while let index = stack.popLast() {
            let x = index % width
            let y = index / width
            push(x + 1, y)
            push(x - 1, y)
            push(x, y + 1)
            push(x, y - 1)
        }

        for _ in 0..<3 {
            var clear: [Int] = []
            for y in 1..<(height - 1) {
                for x in 1..<(width - 1) {
                    let index = y * width + x
                    let offset = index * 4
                    if pixels[offset + 3] == 0 { continue }
                    guard isOuterWhite(offset) else { continue }
                    let neighbors = [index - 1, index + 1, index - width, index + width]
                    if neighbors.contains(where: { pixels[$0 * 4 + 3] == 0 }) {
                        clear.append(index)
                    }
                }
            }
            for index in clear {
                pixels[index * 4 + 3] = 0
            }
        }
    }

    var minX = side
    var minY = side
    var maxX = 0
    var maxY = 0
    mutate(rep) { pixels, width, height in
        for y in 0..<height {
            for x in 0..<width {
                if pixels[(y * width + x) * 4 + 3] < 12 { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }
    guard maxX > minX, maxY > minY,
          let cropped = rep.cgImage?.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
    else {
        return NSImage(cgImage: rep.cgImage!, size: NSSize(width: side, height: side))
    }

    let filled = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: side,
        pixelsHigh: side,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: side * 4,
        bitsPerPixel: 32
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: filled)
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: side, height: side).fill()
    let artwork = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    let bleed: CGFloat = 1.04
    let scale = max(CGFloat(side) / CGFloat(cropped.width), CGFloat(side) / CGFloat(cropped.height)) * bleed
    let drawWidth = CGFloat(cropped.width) * scale
    let drawHeight = CGFloat(cropped.height) * scale
    artwork.draw(
        in: NSRect(
            x: (CGFloat(side) - drawWidth) / 2,
            y: (CGFloat(side) - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        )
    )
    NSGraphicsContext.restoreGraphicsState()
    return NSImage(cgImage: filled.cgImage!, size: NSSize(width: side, height: side))
}

func templateMenuIcon(_ image: NSImage) -> NSImage {
    let side = 1024
    let rep = bitmap(image, width: side, height: side)
    var minX = side
    var minY = side
    var maxX = 0
    var maxY = 0
    mutate(rep) { pixels, width, height in
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Int(pixels[offset])
                let g = Int(pixels[offset + 1])
                let b = Int(pixels[offset + 2])
                let a = Int(pixels[offset + 3])
                let luminance = max(r, max(g, b))
                let visible = a > 12 && luminance > 18
                if visible {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }
    }
    if maxX <= minX || maxY <= minY {
        minX = 0
        minY = 0
        maxX = side - 1
        maxY = side - 1
    }
    let pad = Int(Double(max(maxX - minX, maxY - minY)) * 0.08)
    minX = max(0, minX - pad)
    minY = max(0, minY - pad)
    maxX = min(side - 1, maxX + pad)
    maxY = min(side - 1, maxY + pad)
    let crop = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    let cropped = rep.cgImage!.cropping(to: crop)!
    let output = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 72,
        pixelsHigh: 72,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 72 * 4,
        bitsPerPixel: 32
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: output)
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: 72, height: 72).fill()
    let source = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    source.draw(in: NSRect(x: 0, y: 0, width: 72, height: 72))
    NSGraphicsContext.restoreGraphicsState()
    mutate(output) { pixels, width, height in
        for index in 0..<(width * height) {
            let offset = index * 4
            let luminance = max(pixels[offset], max(pixels[offset + 1], pixels[offset + 2]))
            let alpha = pixels[offset + 3]
            let visible = alpha > 12 && luminance > 18
            pixels[offset] = 0
            pixels[offset + 1] = 0
            pixels[offset + 2] = 0
            pixels[offset + 3] = visible ? max(alpha, luminance) : 0
        }
    }
    return NSImage(cgImage: output.cgImage!, size: NSSize(width: 18, height: 18))
}

func render(_ image: NSImage, pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: pixels * 4,
        bitsPerPixel: 32
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func bitmap(_ image: NSImage, width: Int, height: Int) -> NSBitmapImageRep {
    render(image, pixels: width)
}

func mutate(_ rep: NSBitmapImageRep, _ body: (UnsafeMutablePointer<UInt8>, Int, Int) -> Void) {
    guard let pixels = rep.bitmapData else { return }
    body(pixels, rep.pixelsWide, rep.pixelsHigh)
}

func pngData(_ image: NSImage) -> Data {
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

func pngData(_ rep: NSBitmapImageRep) -> Data {
    rep.representation(using: .png, properties: [:])!
}
