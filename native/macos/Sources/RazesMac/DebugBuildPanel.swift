import RazesCore
import SwiftUI

struct DebugBuildPanel: View {
  @Bindable var session: GameSession
  let state: GameState
  let place: (PlacementTool) -> Void
  @State private var instant = true
  @State private var selected: BuildingID = .woodshed
  @State private var level = 1
  @State private var condition = 100.0
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Building workshop").font(.system(size: 24, design: .serif))
      Toggle("Complete instantly", isOn: $instant)
      Text(
        "Instant placement and debug edits cost nothing. Seasonal placement pays the normal price."
      )
      .font(.caption).foregroundStyle(GamePalette.gold)
      ForEach(Construction.definitions) { d in
        Button("Place \(d.title.lowercased())") {
          place(.building(d.id, worker: nil, instant: instant))
        }
        .disabled(Construction.stage(d.id, state: state) != .empty)
      }
      Button("Finish all construction") {
        for r in state.buildings where r.level == 0 { session.finishConstruction(r.id) }
        for id in BuildingID.allCases where Construction.stage(id, state: state) == .planned {
          session.finishConstruction(id)
        }
      }
      Divider()
      Text("LEVELS & CONDITION").font(.caption).foregroundStyle(GamePalette.gold)
      Picker("Building", selection: $selected) {
        ForEach(Construction.definitions) { d in Text(d.title).tag(d.id) }
      }
      Stepper("Level \(level) / 5", value: $level, in: 1...5)
      Slider(value: $condition, in: 0...100, step: 1) { Text("Condition") }
      Text("Condition: \(Int(condition))%").font(.caption)
      Button("Apply level and condition") {
        session.debugSetBuilding(selected, level: level, condition: condition)
      }
      .disabled(!state.buildings.contains { $0.id == selected })
      Button("Add 100 Galbeni and food") { session.debugResources() }
      Picker(
        "Season preview",
        selection: Binding(
          get: { state.debugSeason ?? -1 }, set: { session.previewSeason($0 == -1 ? nil : $0) })
      ) {
        Text("Actual season").tag(-1)
        ForEach(0..<4, id: \.self) { Text(Content.seasons[$0]).tag($0) }
      }
      Text(
        "Preview changes scenery and weather only. Production and wear run when a season resolves, and upgrades/repairs are immediate."
      ).font(.caption).foregroundStyle(GamePalette.muted)
      Divider()
      Text("SCENERY").font(.caption).foregroundStyle(GamePalette.gold)
      ForEach(SceneryKind.allCases, id: \.self) { kind in
        Button("Place \(kind.rawValue)") { place(.scenery(kind)) }
      }
      Button("Clear debug scenery") { session.removeScenery() }.disabled(
        state.layout.scenery.isEmpty)
    }.buttonStyle(.bordered).frame(maxWidth: .infinity, alignment: .leading)
  }
}
