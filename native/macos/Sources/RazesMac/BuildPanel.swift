import RazesCore
import SwiftUI

struct BuildPanel: View {
  let state: GameState
  let select: (BuildingID) -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Shape the homestead").font(.system(size: 23, design: .serif))
      Text("One adult’s season. A lasting change.").font(.caption).foregroundStyle(
        GamePalette.muted)
      ForEach(Construction.definitions) { definition in
        Button {
          select(definition.id)
        } label: {
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(definition.title).font(.headline)
              Spacer()
              Text("\(definition.cost) coins").foregroundStyle(GamePalette.gold)
            }
            Text(definition.benefit).font(.caption).multilineTextAlignment(.leading).lineLimit(nil)
              .fixedSize(horizontal: false, vertical: true)
            Text(status(definition.id)).font(.caption).foregroundStyle(GamePalette.muted)
          }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }.buttonStyle(.bordered)
      }
      Text("Benefits begin the following season. Drafts remain editable until you confirm work.")
        .font(.caption).foregroundStyle(GamePalette.muted)
    }
  }
  private func status(_ id: BuildingID) -> String {
    if let reason = Construction.unavailable(id, state: state) { return reason }
    return Construction.stage(id, state: state) == .planned
      ? "Worker assigned · construction planned" : "Select plot and assign a worker"
  }
}
