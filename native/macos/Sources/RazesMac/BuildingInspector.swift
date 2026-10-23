import RazesCore
import SwiftUI

struct BuildingInspector: View {
  @Bindable var session: GameSession
  let state: GameState
  let id: BuildingID
  let beginPlacement: (PlacementTool) -> Void
  var body: some View {
    let d = Construction.definition(id)
    VStack(alignment: .leading, spacing: 12) {
      Text(d.title).font(.system(size: 25, design: .serif))
      Text(d.benefit).font(.callout)
      if let r = state.buildings.first(where: { $0.id == id }) {
        HStack {
          Text(r.level == 0 ? "FOUNDATION" : "LEVEL \(r.level) / 5").font(.headline)
            .foregroundStyle(GamePalette.gold)
          Spacer()
          Text("\(Int(r.condition))% condition").monospacedDigit()
        }
        ProgressView(value: r.condition, total: 100).tint(
          r.condition < 30 ? .orange : GamePalette.gold
        )
        .accessibilityLabel("Building condition")
        if r.level == 0 {
          Text("Foundation · completes at season end").foregroundStyle(GamePalette.gold)
        } else {
          Text(
            r.condition > 0 ? d.yieldText(level: r.level) : "Inactive · repair to resume production"
          ).foregroundStyle(GamePalette.gold)
          if r.level < 5 {
            Text(Construction.materialCost(id).scaled(r.level + 1).text).font(.caption)
            Button("Upgrade to level \(r.level + 1) · \(Construction.upgradeCost(r)) coins") {
              session.upgradeBuilding(id)
            }
            Text("Immediate · \(d.yieldText(level: r.level + 1))").font(
              .caption
            ).foregroundStyle(GamePalette.muted)
          } else {
            Label("Maximum level reached", systemImage: "checkmark.seal").font(.caption)
          }
          Text("Repair supplies: \(Construction.repairMaterials(id).text)").font(.caption)
          Button("Repair · \(Construction.repairCost(id)) coins · immediate") {
            session.repairBuilding(id)
          }.disabled(r.condition >= 100)
        }
        Text(
          "Wear: 20 condition per season. At zero: lose one level and return to 60 condition. Level 1 becomes inactive until repaired."
        ).font(.caption).foregroundStyle(GamePalette.muted)
      } else if Construction.stage(id, state: state) == .planned {
        Text("Seasonal plan · completes when Ion’s work resolves.").font(.caption)
        Button("Remove seasonal plan") { session.removePlan(id) }
      } else {
        Text(Construction.priceText(id)).foregroundStyle(GamePalette.gold)
        Text("Completes at season end").font(.caption)
        Text(d.yieldText(level: 1)).font(.caption)
        Button("Choose building location") {
          beginPlacement(.building(id, worker: nil, instant: false))
        }
      }
      if let position = Settlement.position(for: id, in: state.layout) {
        Divider()
        Text("Plot: \(position.x), \(position.y)").font(.caption).foregroundStyle(GamePalette.muted)
        Button("Rotate building 90°") { session.rotateBuilding(id) }
        Button("Move building plot") { beginPlacement(.building(id, worker: nil, instant: false)) }
      }
    }.buttonStyle(.bordered)
  }
}
