import RazesCore

enum Hotspot: String, CaseIterable, Hashable { case field, house, visitor, stores }
enum SceneSelection: Equatable {
  case worker(WorkerID)
  case hotspot(Hotspot)
  case building(BuildingID)
  case scenery(String)
}
enum PlacementTool: Equatable {
  case building(BuildingID, worker: WorkerID?, instant: Bool)
  case scenery(SceneryKind)
  var kind: StructureKind {
    switch self {
    case .building(let id, _, _): .building(id)
    case .scenery(let kind): .scenery(kind)
    }
  }
  var title: String {
    switch self {
    case .building(let id, _, _): Construction.definition(id).title
    case .scenery(let kind): kind.rawValue.capitalized
    }
  }
}
struct GameUIState {
  var selection: SceneSelection?
  var buildMode = false
  var review = true
  var debug = false
  var placement: PlacementTool?
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
