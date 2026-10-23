import CoreGraphics
import XCTest

@testable import RazesMac

final class CameraTests: XCTestCase {
  let viewport = CGSize(width: 1200, height: 760)
  func testZoomKeepsPointerAnchoredAndClampsScaleAndPan() {
    var camera = CameraState()
    let anchor = CGPoint(x: 650, y: 240)
    let offset = CGPoint(
      x: (anchor.x - camera.center.x) / camera.scale, y: (anchor.y - camera.center.y) / camera.scale
    )
    camera.zoom(by: 0.8, anchor: anchor, viewport: viewport)
    XCTAssertEqual((anchor.x - camera.center.x) / camera.scale, offset.x, accuracy: 0.001)
    XCTAssertEqual((anchor.y - camera.center.y) / camera.scale, offset.y, accuracy: 0.001)
    camera.zoom(by: 0.00001, anchor: camera.center, viewport: viewport)
    XCTAssertEqual(camera.scale, 0.55)
    camera.pan(by: CGPoint(x: 99999, y: -99999), viewport: viewport)
    XCTAssertLessThanOrEqual(
      camera.center.x, CameraState.bounds.maxX - viewport.width * camera.scale / 2)
    XCTAssertGreaterThanOrEqual(
      camera.center.y, CameraState.bounds.minY + viewport.height * camera.scale / 2)
    camera.zoom(by: 10000, anchor: camera.center, viewport: viewport)
    XCTAssertEqual(camera.scale, 2.4)
    XCTAssertEqual(camera.center.x, CameraState.bounds.midX)
    camera.reset(viewport: viewport)
    XCTAssertEqual(camera, CameraState())
  }
}
