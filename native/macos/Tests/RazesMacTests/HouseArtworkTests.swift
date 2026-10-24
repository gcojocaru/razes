import AppKit
import RazesCore
import SpriteKit
import XCTest

@testable import RazesMac

final class HouseArtworkTests: XCTestCase {
  @MainActor func testUpgradeHasDistinctSeasonalAndDamagedArtForEveryView() throws {
    let scene = HomesteadScene()
    for facing in 0..<4 {
      var variants: [SKTexture] = []
      for winter in [false, true] {
        for damaged in [false, true] {
          let starter = try XCTUnwrap(
            scene.houseTexture(level: 1, damaged: damaged, winter: winter, facing: facing))
          let upgraded = try XCTUnwrap(
            scene.houseTexture(level: 2, damaged: damaged, winter: winter, facing: facing))
          XCTAssertFalse(starter === upgraded)
          XCTAssertFalse(variants.contains { $0 === upgraded })
          variants.append(upgraded)
          for level in 3...5 {
            XCTAssertTrue(
              upgraded
                === scene.houseTexture(
                  level: level, damaged: damaged, winter: winter, facing: facing))
          }
        }
      }
    }
    XCTAssertNil(scene.resourceWarning)
  }

  @MainActor func testHouseUpdatesKeepFootprintAnchorAndNodeCount() throws {
    let scene = HomesteadScene()
    var state = Rules.newGame()
    scene.update(state: state, reducedMotion: true)
    let house = try XCTUnwrap(scene.childNode(withName: "//house") as? SKSpriteNode)
    let children = house.children.count
    for level in 1...5 {
      for rotation in 0..<4 {
        for winter in [false, true] {
          for damaged in [false, true] {
            state.houseLevel = level
            state.layout.viewRotation = rotation
            state.debugSeason = winter ? 3 : 1
            state.house = damaged ? 20 : 100
            scene.update(state: state, reducedMotion: true)
            XCTAssertTrue(scene.childNode(withName: "//house") === house)
            XCTAssertEqual(house.children.count, children)
            XCTAssertEqual(house.anchorPoint, CGPoint(x: 0.5, y: 0))
            XCTAssertEqual(house.size.width, 240)
            XCTAssertEqual(house.xScale, rotation % 2 == 0 ? 1 : -1)
            XCTAssertTrue(
              house.texture
                === scene.houseTexture(
                  level: level, damaged: damaged, winter: winter, facing: rotation))
            XCTAssertNil(scene.resourceWarning)
          }
        }
      }
    }
  }

  @MainActor func testCatalogueImagesHaveVisiblePixelsWithoutSpriteKitRenderer() throws {
    for facing in 0..<4 {
      for winter in [false, true] {
        for damaged in [false, true] {
          for level in [1, 2] {
            let image = try XCTUnwrap(
              HomesteadScene.houseArtworkImage(
                level: level, damaged: damaged, winter: winter, facing: facing))
            let cgImage = try XCTUnwrap(
              image.cgImage(forProposedRect: nil, context: nil, hints: nil))
            XCTAssertGreaterThan(cgImage.width, 0)
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            let center = bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)
            XCTAssertGreaterThan(try XCTUnwrap(center).alphaComponent, 0.5)
          }
        }
        for id in BuildingID.allCases {
          XCTAssertNotNil(
            HomesteadScene.buildingArtworkImage(
              id, level: 1, planned: false, winter: winter, facing: facing))
        }
      }
    }
  }
}
