import RazesCore
import SwiftUI

struct BuildPanel: View {
  let state: GameState
  let select: (BuildingID) -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Grow the settlement").font(.system(size: 23, design: .serif))
      Text("10 buildings · 5 levels each").font(.caption).foregroundStyle(GamePalette.gold)
      Text(
        "Choose a building, then place it on free ground. Construction starts immediately; household workers keep their seasonal assignments."
      ).font(.caption).foregroundStyle(GamePalette.muted)
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
            Text(definition.yieldText(level: 1)).font(.caption).foregroundStyle(GamePalette.gold)
            Text(status(definition)).font(.caption).foregroundStyle(GamePalette.muted)
          }.multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }.buttonStyle(.bordered)
      }
      Text(
        "Income scales with level. Maintain buildings before they lose a level. Timers continue after the story ends."
      ).font(.caption).foregroundStyle(GamePalette.muted)
    }
  }
  private func status(_ d: BuildingDefinition) -> String {
    if let r = state.buildings.first(where: { $0.id == d.id }) {
      if let work = r.work {
        return "\(work.kind.rawValue.capitalized) · \(Int(work.remaining.rounded(.up)))s remaining"
      }
      return "Level \(r.level)/5 · condition \(Int(r.condition))% · select to manage"
    }
    return "\(Int(d.buildTime))s to build · click to choose location"
  }
}
