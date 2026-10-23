import RazesCore

enum Hotspot: String, CaseIterable, Hashable { case field, house, visitor, stores }
enum SceneSelection: Equatable {
  case worker(WorkerID)
  case hotspot(Hotspot)
  case building(BuildingID)
}
struct GameUIState {
  var selection: SceneSelection?
  var buildMode = false
  var review = true
  mutating func dismissOptional() {
    selection = nil
    buildMode = false
    review = false
  }
  mutating func changedPhase() {
    selection = nil
    buildMode = false
    review = true
  }
}
