import Foundation
import XCTest

@testable import RazesCore

final class FarmlandTests: XCTestCase {
  private func save(tiles: [[String: Int]]?) throws -> Data {
    var json = try XCTUnwrap(
      JSONSerialization.jsonObject(with: SaveCodec.encode(Rules.newGame())) as? [String: Any])
    var layout = try XCTUnwrap(json["layout"] as? [String: Any])
    layout["farmland"] = tiles
    json["layout"] = layout
    return try JSONSerialization.data(withJSONObject: json)
  }
  func testMissingFarmlandPreservesOldFieldAndEmptyFarmlandStaysEmpty() throws {
    let old = try SaveCodec.decode(save(tiles: nil))
    let json = try XCTUnwrap(
      JSONSerialization.jsonObject(with: SaveCodec.encode(old)) as? [String: Any])
    let layout = try XCTUnwrap(json["layout"] as? [String: Any])
    XCTAssertEqual((layout["farmland"] as? [[String: Int]])?.count, 9)
    let empty = try SaveCodec.decode(save(tiles: []))
    XCTAssertFalse(Rules.taskOptions(empty).contains { $0.id == .plant })
    XCTAssertNotNil(Rules.assignmentProblem(empty, worker: .ion, task: .plant))
  }
  func testInvalidFarmlandIsRejectedAtLoad() throws {
    for tiles in [
      [["x": -1, "y": 0]], [["x": 16, "y": 0]],
      [["x": 1, "y": 1], ["x": 1, "y": 1]], [["x": 6, "y": 6]],
    ] {
      XCTAssertThrowsError(try SaveCodec.decode(save(tiles: tiles)), "\(tiles)")
    }
  }
  func testRelocatedFarmlandReservesOnlyItsCurrentCells() throws {
    let state = try SaveCodec.decode(save(tiles: [["x": 1, "y": 1]]))
    XCTAssertNotNil(
      Settlement.problem(.infrastructure(.pavement), at: .init(x: 1, y: 1), layout: state.layout))
    XCTAssertNil(
      Settlement.problem(.infrastructure(.pavement), at: .init(x: 5, y: 10), layout: state.layout))
  }
}
