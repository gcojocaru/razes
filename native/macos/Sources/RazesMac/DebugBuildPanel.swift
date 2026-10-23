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
      Text("Instant placement and debug edits cost nothing. Timed placement pays the normal price.")
        .font(.caption).foregroundStyle(GamePalette.gold)
      ForEach(Construction.definitions) { d in
        Button("Place \(d.title.lowercased())") {
          place(.building(d.id, worker: nil, instant: instant))
        }
        .disabled(Construction.stage(d.id, state: state) != .empty)
      }
      Button("Finish all construction") {
        for r in state.buildings where r.work != nil { session.finishConstruction(r.id) }
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
      Button("Add 100 coins and food") { session.debugResources() }
      HStack {
        Button("Advance 1 hour") { session.debugAdvance(3600) }
        Button("Advance 24 hours") { session.debugAdvance(86400) }
      }
      Text(
        "Time jumps affect production, work and decay; the story season stays where it is. Offline catch-up is limited to 24 hours."
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
