import RazesCore

enum Hotspot: String, CaseIterable, Hashable { case field, house, stores }
enum SceneSelection: Equatable {
  case worker(WorkerID)
  case hotspot(Hotspot)
  case building(BuildingID)
  case scenery(String)
}
enum PlacementTool: Equatable {
  case building(BuildingID, worker: WorkerID?, instant: Bool)
  case scenery(SceneryKind)
  case infrastructure(InfrastructureKind)
  var isFence: Bool {
    if case .infrastructure(let kind) = self { return kind.isFence }
    return false
  }
  var kind: StructureKind {
    switch self {
    case .building(let id, _, _): .building(id)
    case .scenery(let kind): .scenery(kind)
    case .infrastructure(let kind): .infrastructure(kind)
    }
  }
  var title: String {
    switch self {
    case .building(let id, _, _): Construction.definition(id).title
    case .scenery(let kind): kind.rawValue.capitalized
    case .infrastructure(let kind): kind.title
    }
  }
}
struct GameUIState {
  var selection: SceneSelection?
  var buildMode = false
  var review = true
  var debug = false
  var placement: PlacementTool?
  var placementFacing = 0
  mutating func dismissOptional() {
    placement = nil
    debug = false
    selection = nil
    buildMode = false
    review = false
  }
  mutating func changedPhase() {
    placement = nil
    debug = false
    selection = nil
    buildMode = false
    review = true
  }
}
