import XCTest
@testable import RazesCore
final class SaveTests: XCTestCase {
    func testEveryReferencePhaseRoundTrips() throws {
        for run in try Reference.load().runs {
            for step in run.steps { XCTAssertEqual(try SaveCodec.decode(SaveCodec.encode(step.state)), step.state) }
        }
    }
    func testRejectsMalformedUnsupportedAndContradictorySaves() throws {
        for raw in ["{", "null", "[]", "{}", "{\"version\":99}"] { XCTAssertThrowsError(try SaveCodec.decode(Data(raw.utf8))) }
        let badFields: [[String: Any]] = [["food": -1], ["revision": -1], ["season": 4], ["house": 101], ["trust": 6], ["planted": "yes"], ["tended": true], ["cropBonus": 10], ["reservedWorker": "petru"], ["ox": "paid"], ["assignments": ["ion": "plant"]], ["history": [[:]]], ["memories": [[:]]], ["hardship": [[:]]], ["report": [:]], ["version": 99]]
        let original = try JSONSerialization.jsonObject(with: SaveCodec.encode(Rules.newGame())) as! [String: Any]
        for changes in badFields {
            var json = original; changes.forEach { json[$0.key] = $0.value }
            XCTAssertThrowsError(try SaveCodec.decode(JSONSerialization.data(withJSONObject: json)), "\(changes)")
        }
        for run in try Reference.load().runs {
            for step in run.steps where step.state.reservedWorker != nil {
                var wrong = step.state; wrong.reservedWorker = nil
                XCTAssertThrowsError(try SaveCodec.decode(SaveCodec.encode(wrong)))
            }
        }
    }
}
