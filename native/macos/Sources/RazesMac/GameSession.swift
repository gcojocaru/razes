import Foundation
import Observation
import RazesCore

@MainActor @Observable final class GameSession {
  private(set) var state = Rules.newGame()
  private(set) var needsRecovery = false
  private(set) var hasSaved = false
  private(set) var acceptedRevision: Int?
  var error: String?
  var storageWarning: String?
  private let store: SaveStore?
  let audio = Ambience()
  var soundEnabled = false { didSet { audio.setEnabled(soundEnabled && active) } }
  var active = true { didSet { audio.setEnabled(soundEnabled && active) } }
  var reduceMotion = false
  init(store: SaveStore?, startupError: String? = nil) {
    self.store = store
    if let startupError { storageWarning = startupError } else { retryLoad() }
  }
  static func applicationSession(arguments: [String] = CommandLine.arguments) -> GameSession {
    #if DEBUG
      if let index = arguments.firstIndex(of: "--validation-save"), index + 1 < arguments.count {
        return GameSession(store: SaveStore(url: URL(fileURLWithPath: arguments[index + 1])))
      }
    #endif
    do { return GameSession(store: try SaveStore.applicationStore()) } catch {
      return GameSession(
        store: nil, startupError: "Saving is unavailable: \(error.localizedDescription)")
    }
  }
  func retryLoad() {
    acceptedRevision = nil
    guard let store else { return }
    do {
      if let loaded = try store.load() {
        state = loaded
        hasSaved = true
      } else {
        state = Rules.newGame()
        hasSaved = false
      }
      needsRecovery = false
      error = nil
      storageWarning = nil
    } catch {
      needsRecovery = true
      self.error = error.localizedDescription
    }
  }
  func send(_ action: Action) {
    guard !needsRecovery else { return }
    do {
      accept(try Rules.dispatch(state, action: action))
    } catch { self.error = error.localizedDescription }
  }
  private func accept(_ next: GameState) {
    state = next
    acceptedRevision = next.revision
    error = nil
    do {
      guard let store else { throw GameError("The save location is unavailable.") }
      try store.save(state)
      storageWarning = nil
      hasSaved = true
    } catch {
      storageWarning =
        "Your run continues, but changes could not be saved: \(error.localizedDescription)"
    }
    audio.cue()
  }
  @discardableResult private func editSettlement(_ edit: (inout GameState) throws -> Void) -> Bool {
    guard !needsRecovery else { return false }
    do {
      var next = state
      try edit(&next)
      next.revision += 1
      _ = try SaveCodec.decode(SaveCodec.encode(next))
      accept(next)
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
  @discardableResult func placeBuilding(
    _ id: BuildingID, at position: GridPosition, instant: Bool = false
  ) -> Bool {
    editSettlement { next in
      if !instant && next.phase != .work {
        throw GameError("Place construction during seasonal planning.")
      }
      if let problem = Settlement.problem(.building(id), at: position, layout: next.layout) {
        throw GameError(problem)
      }
      next.layout.buildings.removeAll { $0.id == id }
      next.layout.buildings.append(.init(id: id, position: position))
      if instant && !next.buildings.contains(where: { $0.id == id }) {
        next.buildings.append(.init(id: id, completedSeason: next.season, debugPlaced: true))
        for worker in WorkerID.allCases
        where next.assignments[worker.rawValue] == Construction.definition(id).task {
          next.assignments[worker.rawValue] = .rest
        }
      }
    }
  }
  @discardableResult func placeScenery(_ kind: SceneryKind, at position: GridPosition) -> Bool {
    editSettlement { next in
      if let problem = Settlement.problem(.scenery(kind), at: position, layout: next.layout) {
        throw GameError(problem)
      }
      next.layout.scenery.append(.init(kind: kind, position: position))
    }
  }
  func finishConstruction(_ id: BuildingID) {
    guard
      let position = Settlement.position(for: id, in: state.layout)
        ?? Settlement.firstAvailable(id, in: state.layout)
    else {
      error = "No free space remains."
      return
    }
    placeBuilding(id, at: position, instant: true)
  }
  func removePlan(_ id: BuildingID) {
    editSettlement { next in
      guard !next.buildings.contains(where: { $0.id == id }) else {
        throw GameError("Completed buildings cannot be removed from a live household.")
      }
      next.layout.buildings.removeAll { $0.id == id }
      for worker in WorkerID.allCases
      where next.assignments[worker.rawValue] == Construction.definition(id).task {
        next.assignments[worker.rawValue] = .rest
      }
    }
  }
  func removeScenery(_ id: String? = nil) {
    editSettlement { next in next.layout.scenery.removeAll { id == nil || $0.id == id } }
  }
  func startFresh() {
    let fresh = Rules.newGame()
    do {
      guard let store else { throw GameError("The save location is unavailable.") }
      try store.startFresh(fresh)
      acceptedRevision = nil
      state = fresh
      needsRecovery = false
      error = nil
      storageWarning = nil
      hasSaved = true
    } catch { self.error = "Could not safely start fresh: \(error.localizedDescription)" }
  }
}
