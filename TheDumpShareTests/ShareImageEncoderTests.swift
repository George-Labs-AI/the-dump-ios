import XCTest
import UIKit
@testable import TheDumpShare

final class ShareImageEncoderTests: XCTestCase {

    /// A solid-color PNG of the given size.
    private func makePNG(width: Int, height: Int) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }())
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return try XCTUnwrap(image.pngData())
    }

    func test_jpegData_convertsPNGToJPEG() throws {
        let png = try makePNG(width: 40, height: 30)

        let jpeg = try XCTUnwrap(ShareImageEncoder.jpegData(from: png))

        // JPEG SOI marker
        XCTAssertEqual(Array(jpeg.prefix(2)), [0xFF, 0xD8])
        let decoded = try XCTUnwrap(UIImage(data: jpeg))
        XCTAssertEqual(Int(decoded.size.width * decoded.scale), 40)
        XCTAssertEqual(Int(decoded.size.height * decoded.scale), 30)
    }

    func test_jpegData_downscalesToMaxPixelSize() throws {
        let png = try makePNG(width: 400, height: 200)

        let jpeg = try XCTUnwrap(ShareImageEncoder.jpegData(from: png, maxPixelSize: 100))

        let decoded = try XCTUnwrap(UIImage(data: jpeg))
        XCTAssertEqual(Int(decoded.size.width * decoded.scale), 100)
        XCTAssertEqual(Int(decoded.size.height * decoded.scale), 50)
    }

    func test_jpegData_returnsNilForNonImageBytes() {
        XCTAssertNil(ShareImageEncoder.jpegData(from: Data("not an image".utf8)))
    }

    func test_thumbnail_isBoundedByMaxPixelSize() throws {
        let png = try makePNG(width: 1000, height: 1000)

        let thumbnail = try XCTUnwrap(ShareImageEncoder.thumbnail(from: png, maxPixelSize: 120))

        XCTAssertLessThanOrEqual(Int(thumbnail.size.width * thumbnail.scale), 120)
        XCTAssertLessThanOrEqual(Int(thumbnail.size.height * thumbnail.scale), 120)
    }
}
