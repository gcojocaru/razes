import RazesCore
import SwiftUI

struct DebugBuildPanel: View {
  @Bindable var session: GameSession
  let state: GameState
  let place: (PlacementTool) -> Void
  @State private var instant = true
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Building workshop").font(.system(size: 24, design: .serif))
      Toggle("Complete instantly", isOn: $instant)
      Text("Debug completion spends nothing. Building benefits still begin next season.").font(
        .caption
      ).foregroundStyle(GamePalette.gold)
      ForEach(Construction.definitions) { definition in
        Button("Place \(definition.title.lowercased())") {
          place(.building(definition.id, worker: nil, instant: instant))
        }
        .disabled(
          state.buildings.contains(where: { $0.id == definition.id })
            || !instant && state.phase != .work)
      }
      Button("Finish planned construction") {
        for id in BuildingID.allCases where Construction.stage(id, state: state) == .planned {
          session.finishConstruction(id)
        }
      }.disabled(!BuildingID.allCases.contains { Construction.stage($0, state: state) == .planned })
      Divider()
      Text("SCENERY").font(.caption).foregroundStyle(GamePalette.gold)
      ForEach(SceneryKind.allCases, id: \.self) { kind in
        Button("Place \(kind.rawValue)") { place(.scenery(kind)) }
      }
      Text("Scenery uses space but has no resource bonus. All positions save with this household.")
        .font(.caption).foregroundStyle(GamePalette.muted)
      Button("Clear debug scenery") { session.removeScenery() }.disabled(
        state.layout.scenery.isEmpty)
    }.buttonStyle(.bordered).frame(maxWidth: .infinity, alignment: .leading)
  }
}
