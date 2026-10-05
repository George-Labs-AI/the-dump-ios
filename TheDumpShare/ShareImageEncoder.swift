import Foundation
import ImageIO
import UIKit

/// Turns shared image bytes (JPEG, PNG, HEIC, ...) into a JPEG the backend's
/// photo pipeline already accepts, matching what the main app's camera path
/// uploads.
///
/// Decodes through ImageIO's thumbnail API so a 12MP photo never has to be
/// fully decoded in memory: share extensions run under a tight memory limit
/// (~120MB) and a single full-size decode can exceed it.
enum ShareImageEncoder {
    /// Longest edge of the uploaded image. 4096px keeps screenshots and
    /// documents legible for OCR while bounding memory and upload size.
    static let defaultMaxPixelSize = 4096

    static let jpegQuality: CGFloat = 0.85

    static func jpegData(
        from imageData: Data,
        maxPixelSize: Int = defaultMaxPixelSize,
        quality: CGFloat = jpegQuality
    ) -> Data? {
        guard let cgImage = decode(imageData, maxPixelSize: maxPixelSize) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
    }

    /// A small preview for the share sheet.
    static func thumbnail(from imageData: Data, maxPixelSize: Int = 240) -> UIImage? {
        guard let cgImage = decode(imageData, maxPixelSize: maxPixelSize) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func decode(_ imageData: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Bake EXIF orientation into the pixels so the upload is upright.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
