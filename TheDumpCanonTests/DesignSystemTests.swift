import XCTest
import UIKit
@testable import The_Dump

/// The shared pieces of the restyle to The Dump Design System: the bundled
/// display font loads, and the colour names the screens use resolve to the
/// design system's dark values (the app is dark-only for now).
@MainActor
final class DesignSystemTests: XCTestCase {
    func testDisplayFontIsBundledAndRegisters() async throws {
        DesignFonts.register()
        DesignFonts.register() // A second call must be harmless.
        let font = try XCTUnwrap(UIFont(name: DesignFonts.displayName, size: 40))
        XCTAssertEqual(font.familyName, "Instrument Sans")
    }

    func testDarkPaletteMatchesTheDesignSystem() async throws {
        let expected: [String: String] = [
            "background": "000000",
            "surface": "1C1C1E",
            "surface2": "2C2C2E",
            "surface3": "2C2C2E",
            "border": "2C2C2E",
            "borderLight": "2C2C2E",
            "textPrimary": "F5F5F7",
            "textSecondary": "8E8E93",
            "textTertiary": "6E6E73",
            "textQuaternary": "6E6E73",
            "AccentColor": "F5F5F7",
            "amber": "E1A51C",
            "destructive": "FF453A"
        ]
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        for (name, hex) in expected {
            let color = try XCTUnwrap(UIColor(named: name, in: Bundle(for: AppState.self), compatibleWith: dark),
                                      "\(name) is missing from the asset catalog")
            XCTAssertEqual(hexString(color.resolvedColor(with: dark)), hex, name)
        }
    }

    func testRetiredStatusColoursAreGone() async throws {
        // Green, orange, blue and purple statuses are banned; their names now
        // point at the monochrome palette instead of their own assets.
        for name in ["success", "warning", "info", "themePurple"] {
            XCTAssertNil(UIColor(named: name, in: Bundle(for: AppState.self), compatibleWith: nil), name)
        }
    }

    private func hexString(_ color: UIColor) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue]
            .map { String(format: "%02X", Int(($0 * 255).rounded())) }
            .joined()
    }
}
