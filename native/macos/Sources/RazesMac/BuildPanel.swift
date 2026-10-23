import RazesCore
import SwiftUI

struct BuildPanel: View {
  let state: GameState
  let infrastructure: (InfrastructureKind) -> Void
  let select: (BuildingID) -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Grow the settlement").font(.system(size: 23, design: .serif))
      Text("\(Construction.definitions.count) buildings · 5 levels each").font(.caption).foregroundStyle(GamePalette.gold)
      Text(
        "Choose a building, then place it on free ground. Foundations finish at season end; household workers keep their assignments."
      ).font(.caption).foregroundStyle(GamePalette.muted)
      Text("ROADS & BOUNDARIES").font(.caption).foregroundStyle(GamePalette.gold)
      HStack {
        Button("Stone pavement") { infrastructure(.pavement) }
        Button("Dirt path") { infrastructure(.dirtPath) }
      }.buttonStyle(.bordered)
      HStack {
        Button("Rail fence") { infrastructure(.fence) }
        Button("Wattle fence") { infrastructure(.wattleFence) }
        Button("Erase") { infrastructure(.erase) }
      }.buttonStyle(.bordered)
      Text("1 coin per tile or edge. Drag to paint; R rotates the fence edge. Erase has no refund.")
        .font(.caption).foregroundStyle(GamePalette.muted)
      Divider()
      ForEach(Construction.definitions) { definition in
        Button {
          select(definition.id)
        } label: {
          VStack(alignment: .leading, spacing: 5) {
            HStack {
              Text(definition.title).font(.headline)
              Spacer()
              Text("\(definition.cost) coins").foregroundStyle(GamePalette.gold)
            }
            Text(definition.benefit).font(.caption).fixedSize(horizontal: false, vertical: true)
            Text(Construction.materialCost(definition.id).text).font(.caption).foregroundStyle(GamePalette.gold)
            Text(definition.yieldText(level: 1)).font(.caption).foregroundStyle(GamePalette.gold)
            Text(status(definition)).font(.caption).foregroundStyle(GamePalette.muted)
          }.multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }.buttonStyle(.bordered)
      }
      Text(
        "Income scales with level. Maintain buildings before they lose a level. Continue settlement seasons after the story ends."
      ).font(.caption).foregroundStyle(GamePalette.muted)
    }
  }
  private func status(_ d: BuildingDefinition) -> String {
    if let r = state.buildings.first(where: { $0.id == d.id }) {
      if r.level == 0 { return "Foundation · completes at season end" }
      return "Level \(r.level)/5 · condition \(Int(r.condition))% · select to manage"
    }
    return "Completes at season end · click to choose location"
  }
}
