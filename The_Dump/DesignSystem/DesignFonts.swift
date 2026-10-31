import CoreText
import Foundation

/// The design system's display face, Instrument Sans, is bundled as one
/// variable font file (Fonts/InstrumentSans-Variable.ttf, Open Font License
/// in Fonts/InstrumentSans-OFL.txt). The app's Info.plist is generated, so
/// the font is registered in code at launch instead of through UIAppFonts.
enum DesignFonts {
    /// PostScript name of the file's regular (400) instance.
    static let displayName = "InstrumentSans-Regular"

    private static let fileName = "InstrumentSans-Variable"

    /// Registers the bundled fonts for this process. Safe to call more than
    /// once; a failure only means headlines use the system font.
    static func register() {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "ttf") else {
            print("⚠️ DesignFonts: \(fileName).ttf is missing from the app bundle")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error),
           let error = error?.takeRetainedValue(),
           CFErrorGetCode(error) != CTFontManagerError.alreadyRegistered.rawValue {
            print("⚠️ DesignFonts: could not register \(fileName): \(error)")
        }
    }
}
