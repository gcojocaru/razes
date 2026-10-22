import XCTest
@testable import RazesCore
final class RulesTests: XCTestCase {
    func testInitialStateMatchesReference() throws {
        let url = Bundle.module.url(forResource: "parity", withExtension: "json", subdirectory: "Fixtures")!
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let state = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json["initial"]!))
        XCTAssertEqual(Rules.newGame(), state)
    }
}

struct Reference: Decodable {
    var initial: GameState
    struct Run: Decodable { var steps: [Step]; var ending: Ending }
    struct Step: Decodable { var action: Action; var state: GameState; var projection: Projection; var presentation: Presentation }
    var runs: [Run]
    static func load() throws -> Reference {
        try JSONDecoder().decode(Self.self, from: Data(contentsOf: Bundle.module.url(forResource: "parity", withExtension: "json", subdirectory: "Fixtures")!))
    }
}
extension RulesTests {
    func testFourHundredYearsMatchReference() throws {
        let reference = try Reference.load()
        var endings = Set<String>(), ox = Set<String>(), fields = Set<String>()
        for run in reference.runs {
            var state = Rules.newGame()
            for step in run.steps {
                state = try Rules.dispatch(state, action: step.action)
                XCTAssertEqual(state, step.state)
                XCTAssertEqual(Rules.preview(state), step.projection)
                XCTAssertEqual(Presentation(state: state), step.presentation)
                fields.insert(Presentation(state: state).field)
            }
            XCTAssertEqual(Rules.ending(state), run.ending)
            endings.insert(run.ending.category); ox.insert(state.ox)
        }
        XCTAssertEqual(endings, ["secure", "cost", "crisis"])
        XCTAssertTrue(Set(["honoured", "broken", "paid", "declined"]).isSubset(of: ox))
        XCTAssertEqual(fields.count, 6)
    }
    func testRejectedActionsPreserveInputAndRevision() throws {
        let original = Rules.newGame()
        XCTAssertThrowsError(try Rules.dispatch(original, action: Action(type: "resolve", revision: 0)))
        XCTAssertThrowsError(try Rules.dispatch(original, action: Action(type: "choose", revision: 1, event: "spring-ox", choice: "borrow")))
        XCTAssertThrowsError(try Rules.dispatch(original, action: Action(type: "choose", revision: 0, event: "winter-friend", choice: "ask")))
        let work = try Rules.dispatch(original, action: Action(type: "choose", revision: 0, event: "spring-ox", choice: "borrow"))
        let planted = try Rules.dispatch(work, action: Action(type: "assign", revision: work.revision, worker: .ion, task: .plant))
        XCTAssertThrowsError(try Rules.dispatch(planted, action: Action(type: "assign", revision: planted.revision, worker: .ana, task: .plant)))
        let resolved = try Rules.dispatch(planted, action: Action(type: "resolve", revision: planted.revision))
        XCTAssertThrowsError(try Rules.dispatch(resolved, action: Action(type: "resolve", revision: resolved.revision)))
        XCTAssertEqual(original, Rules.newGame())
        for run in try Reference.load().runs.prefix(80) {
            let end = run.steps.last!.state
            XCTAssertThrowsError(try Rules.dispatch(end, action: Action(type: "continue", revision: end.revision)))
            for step in run.steps where step.state.phase == .work {
                let state = step.state
                if state.reservedWorker == "petru" { XCTAssertNotNil(Rules.assignmentProblem(state, worker: .petru, task: .paid)) }
                if state.season == 2 && state.planted {
                    var partial = state; partial.assignments = ["ion": .harvest, "ana": .rest, "petru": .rest]
                    XCTAssertFalse(Rules.preview(partial).errors.isEmpty)
                    partial.assignments = ["ion": .harvest, "ana": .harvest, "petru": .harvest]
                    XCTAssertFalse(Rules.preview(partial).errors.isEmpty)
                }
            }
        }
    }
}
