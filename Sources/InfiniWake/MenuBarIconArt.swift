import AppKit

/// Отрисовка вариантов значка менюбара (и превью в настройках).
enum MenuBarIconArt {
    /// Превью в настройках = тот же значок, что в менюбаре, ×2 + небольшой отступ.
    private static let settingsIconScale: CGFloat = 2.0
    private static let settingsCellPadding: CGFloat = 8

    /// Ячейка кнопки: вмещает самый высокий вариант (∞+лампа) при масштабе превью.
    static let settingsPreviewSize = NSSize(
        width: ceil(22 * settingsIconScale) + settingsCellPadding * 2,
        height: ceil(26 * settingsIconScale) + settingsCellPadding * 2
    )

    /// Базовый размер композиции ∞+лампа в менюбаре.
    private static let infinityLampBaseSize = NSSize(width: 22, height: 26)

    /// `infinityLampTopText` — вместо ∞ сверху (таймер); только для `.infinityLamp`, не для превью.
    static func image(
        style: MenuBarIconStyle,
        lit: Bool,
        forPreview: Bool = false,
        infinityLampTopText: String? = nil
    ) -> NSImage {
        let menubarImage: NSImage
        switch style {
        case .infinity:
            menubarImage = makeInfinityIcon(lit: lit)
        case .lamp:
            menubarImage = makeLampIcon(lit: lit, scale: 1.0)
        case .infinityLamp:
            menubarImage = makeInfinityLampIcon(lit: lit, topText: forPreview ? nil : infinityLampTopText)
        }
        if forPreview {
            return makeSettingsPreview(from: menubarImage)
        }
        return menubarImage
    }

    /// Увеличивает значок менюбара и центрирует в ячейке настроек.
    private static func makeSettingsPreview(from menubarImage: NSImage) -> NSImage {
        let scale = settingsIconScale
        let cell = settingsPreviewSize
        let iconW = menubarImage.size.width * scale
        let iconH = menubarImage.size.height * scale
        let image = NSImage(size: cell, flipped: false) { _ in
            let dest = NSRect(
                x: (cell.width - iconW) / 2,
                y: (cell.height - iconH) / 2,
                width: iconW,
                height: iconH
            )
            menubarImage.draw(
                in: dest,
                from: NSRect(origin: .zero, size: menubarImage.size),
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
            )
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func makeInfinityIcon(lit: Bool) -> NSImage {
        let alpha: CGFloat = lit ? 1.0 : 0.35
        let font = NSFont.systemFont(ofSize: 13.5, weight: lit ? .semibold : .regular)
        let text = "∞" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor.withAlphaComponent(alpha)
        ]
        let size = text.size(withAttributes: attributes)
        let width = max(ceil(size.width) + 4, 18)
        let height: CGFloat = 18
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let rect = NSRect(
                x: (width - size.width) / 2,
                y: (height - size.height) / 2,
                width: size.width,
                height: size.height
            )
            text.draw(in: rect, withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Лампа как на логотипе.
    static func makeLampIcon(lit: Bool, scale: CGFloat = 1.0) -> NSImage {
        let width: CGFloat = 22 * scale
        let height: CGFloat = 18 * scale
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            drawLampCapsule(
                in: NSRect(
                    x: 3 * scale,
                    y: 5.5 * scale,
                    width: 16 * scale,
                    height: 7 * scale
                ),
                lit: lit
            )
            return true
        }
        image.isTemplate = false
        return image
    }

    /// ∞ (или таймер) сверху + лампа снизу.
    private static func makeInfinityLampIcon(lit: Bool, topText: String?) -> NSImage {
        let showTimer = topText != nil && !(topText?.isEmpty ?? true)
        let label = (showTimer ? topText! : "∞") as NSString

        let font: NSFont
        if showTimer {
            font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: lit ? .semibold : .regular)
        } else {
            font = NSFont.systemFont(ofSize: 13, weight: lit ? .semibold : .regular)
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor.withAlphaComponent(lit ? 1.0 : 0.35)
        ]
        let textSize = label.size(withAttributes: attributes)
        // Лампа ближе к размеру «только лампа» (16×7), чтобы не выглядела тонкой чертой
        let lampW: CGFloat = 15
        let lampH: CGFloat = 6
        let gap: CGFloat = 3
        let padX: CGFloat = 3
        let padTop: CGFloat = 0.5
        let padBottom: CGFloat = 1
        let contentW = max(textSize.width, lampW)
        let width = max(ceil(contentW + padX * 2), infinityLampBaseSize.width)
        let height = max(
            ceil(textSize.height + gap + lampH + padTop + padBottom),
            infinityLampBaseSize.height
        )

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let textRect = NSRect(
                x: (width - textSize.width) / 2,
                y: height - textSize.height - padTop,
                width: textSize.width,
                height: textSize.height
            )
            label.draw(in: textRect, withAttributes: attributes)

            let lampRect = NSRect(
                x: (width - lampW) / 2,
                y: padBottom,
                width: lampW,
                height: lampH
            )
            drawLampCapsule(in: lampRect, lit: lit)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawLampCapsule(in capsule: NSRect, lit: Bool) {
        if lit {
            let glow = capsule.insetBy(dx: -capsule.height * 0.35, dy: -capsule.height * 0.35)
            NSColor(calibratedRed: 0.78, green: 0.95, blue: 0.05, alpha: 0.28).setFill()
            NSBezierPath(roundedRect: glow, xRadius: glow.height / 2, yRadius: glow.height / 2).fill()
            NSColor(calibratedRed: 0.83, green: 1.0, blue: 0.16, alpha: 1.0).setFill()
        } else {
            NSColor.labelColor.withAlphaComponent(0.22).setFill()
        }
        NSBezierPath(roundedRect: capsule, xRadius: capsule.height / 2, yRadius: capsule.height / 2).fill()
        if lit {
            let highlight = NSRect(
                x: capsule.minX + capsule.width * 0.15,
                y: capsule.minY + capsule.height * 0.22,
                width: capsule.width * 0.7,
                height: max(1.2, capsule.height * 0.28)
            )
            NSColor(calibratedWhite: 1.0, alpha: 0.45).setFill()
            NSBezierPath(roundedRect: highlight, xRadius: 1, yRadius: 1).fill()
        }
    }
}
