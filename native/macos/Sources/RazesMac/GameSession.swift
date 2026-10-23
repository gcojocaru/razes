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
    persist()
    audio.cue()
  }
  private func persist() {
    do {
      guard let store else { throw GameError("The save location is unavailable.") }
      try store.save(state)
      storageWarning = nil
      hasSaved = true
    } catch {
      storageWarning =
        "Your run continues, but changes could not be saved: \(error.localizedDescription)"
    }
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
    _ id: BuildingID, at position: GridPosition, instant: Bool = false, facing: Int? = nil
  ) -> Bool {
    editSettlement { next in
      if let problem = Settlement.problem(.building(id), at: position, layout: next.layout) {
        throw GameError(problem)
      }
      let direction = facing ?? next.layout.buildings.first { $0.id == id }?.facing ?? 0
      next.layout.buildings.removeAll { $0.id == id }
      next.layout.buildings.append(.init(id: id, position: position, facing: direction))
      if !next.buildings.contains(where: { $0.id == id }) {
        if instant {
          next.buildings.append(
            .init(id: id, completedSeason: next.turn, debugPlaced: true, legacyAssignment: false))
          clearLegacyBuilder(id, state: &next)
        } else if Construction.stage(id, state: next) == .empty {
          try Construction.start(id, state: &next)
        }
      }
    }
  }
  @discardableResult func placeScenery(
    _ kind: SceneryKind, at position: GridPosition, facing: Int = 0
  ) -> Bool {
    editSettlement { next in
      if let problem = Settlement.problem(
        .scenery(kind), at: position, layout: next.layout, facing: facing)
      {
        throw GameError(problem)
      }
      next.layout.scenery.append(.init(kind: kind, position: position, facing: facing))
    }
  }
  private func clearLegacyBuilder(_ id: BuildingID, state: inout GameState) {
    guard state.phase == .work, let task = Construction.definition(id).task else { return }
    for worker in WorkerID.allCases where state.assignments[worker.rawValue] == task {
      state.assignments[worker.rawValue] = .rest
    }
  }
  func upgradeBuilding(_ id: BuildingID) {
    editSettlement { try Construction.upgrade(id, state: &$0) }
  }
  func repairBuilding(_ id: BuildingID) {
    editSettlement { try Construction.repair(id, state: &$0) }
  }
  func buyMaterials(_ id: MaterialID, quantity: Int) {
    editSettlement { try Materials.buy(id, quantity: quantity, state: &$0) }
  }
  func craftPlanks(quantity: Int) {
    editSettlement { try Materials.craftPlanks(quantity: quantity, state: &$0) }
  }
  func discardMaterials(_ id: MaterialID, quantity: Int) {
    editSettlement { try Materials.discard(id, quantity: quantity, state: &$0) }
  }
  func upgradeHouseStorage() {
    editSettlement { try Materials.upgradeHouse(state: &$0) }
  }
  func finishConstruction(_ id: BuildingID) {
    if let record = state.buildings.first(where: { $0.id == id }) {
      debugSetBuilding(
        id, level: max(1, record.level),
        condition: 100)
    } else if let position = Settlement.position(for: id, in: state.layout)
      ?? Settlement.firstAvailable(id, in: state.layout)
    {
      placeBuilding(id, at: position, instant: true)
    }
  }
  func debugSetBuilding(_ id: BuildingID, level: Int, condition: Double) {
    editSettlement { next in
      guard (1...5).contains(level), condition.isFinite, (0...100).contains(condition),
        let index = next.buildings.firstIndex(where: { $0.id == id })
      else { throw GameError("Choose an existing building, level 1–5 and condition 0–100.") }
      if next.buildings[index].level == 0 {
        next.buildings[index].completedSeason = next.turn
      }
      next.buildings[index].level = level
      next.buildings[index].condition = condition
      next.buildings[index].debugPlaced = true
      clearLegacyBuilder(id, state: &next)
    }
  }
  func rotateView(_ quarterTurns: Int) {
    editSettlement { $0.layout.viewRotation = ($0.layout.viewRotation + quarterTurns % 4 + 4) % 4 }
  }
  func rotateBuilding(_ id: BuildingID) {
    editSettlement { next in
      guard let index = next.layout.buildings.firstIndex(where: { $0.id == id }) else {
        throw GameError("Place a building first.")
      }
      next.layout.buildings[index].facing = (next.layout.buildings[index].facing + 1) % 4
    }
  }
  func rotateScenery(_ id: String) {
    editSettlement { next in
      guard let index = next.layout.scenery.firstIndex(where: { $0.id == id }) else {
        throw GameError("Select scenery first.")
      }
      next.layout.scenery[index].facing = (next.layout.scenery[index].facing + 1) % 4
    }
  }
  func previewSeason(_ season: Int?) {
    editSettlement { next in
      guard season == nil || (0...3).contains(season!) else {
        throw GameError("Choose a valid visual season.")
      }
      next.debugSeason = season
    }
  }
  @discardableResult func placeInfrastructure(
    _ kind: InfrastructureKind, at point: GridPosition, facing: Int = 0
  ) -> Bool {
    editSettlement { next in
      if let problem = Settlement.infrastructureProblem(
        kind, at: point, state: next, facing: facing)
      {
        throw GameError(problem)
      }
      if kind == .erase {
        next.layout.pavement.removeAll { $0 == point }
        next.layout.dirtPaths.removeAll { $0 == point }
        next.layout.farmland.removeAll { $0 == point }
        let edges = Set((0..<4).map { FenceSegment(position: point, facing: $0).edgeKey })
        next.layout.fences.removeAll { edges.contains($0.edgeKey) }
      } else {
        try Construction.spend(1, state: &next)
        if kind == .pavement {
          next.layout.pavement.append(point)
        } else if kind == .dirtPath {
          next.layout.dirtPaths.append(point)
        } else if kind == .farmland {
          next.layout.farmland.append(point)
        } else {
          next.layout.fences.append(
            .init(position: point, facing: facing, style: kind == .wattleFence ? .wattle : .rail))
        }
      }
    }
  }
  func debugResources() {
    editSettlement {
      $0.money = min(100000, $0.money + 100)
      $0.food = min(100000, $0.food + 100)
    }
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
