import AppKit
import RazesCore
import SwiftUI

struct BuildPanel: View {
  @Bindable var session: GameSession
  let state: GameState
  let infrastructure: (InfrastructureKind) -> Void
  let beginPlacement: (PlacementTool) -> Void
  let close: () -> Void
  var initialSelection: BuildingID? = nil
  @State private var selected: BuildingID?
  @State private var land = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Grow the settlement").font(.system(size: 27, design: .serif))
        Spacer()
        Button("Done", action: close).keyboardShortcut(.cancelAction)
      }
      Picker("Catalogue", selection: $land) {
        Text("House & buildings").tag(false)
        Text("Land & paths").tag(true)
      }.pickerStyle(.segmented)
      if land {
        landControls.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      } else {
        HStack(alignment: .top, spacing: 0) {
          ScrollView {
            VStack(spacing: 5) {
              catalogueRow(
                "House", subtitle: "Level \(state.houseLevel)/5 · storage & blueprints",
                selection: nil)
              ForEach(Construction.definitions) { definition in
                catalogueRow(
                  definition.title,
                  subtitle: ConstructionPresentation.status(definition.id, state: state),
                  selection: definition.id)
              }
            }.padding(8)
          }.frame(width: 236).background(GamePalette.ink)
          Divider()
          ScrollView {
            if let selected {
              BuildingInspector(
                session: session, state: state, id: selected, beginPlacement: beginPlacement
              )
              .padding(20)
            } else {
              HouseConstructionDetail(session: session, state: state).padding(20)
            }
          }.frame(maxWidth: .infinity)
        }.background(GamePalette.panel)
      }
    }.padding(20).frame(width: 900, height: 600)
      .font(.system(size: 14)).foregroundStyle(GamePalette.paper)
      .tint(GamePalette.gold).background(GamePalette.panel).preferredColorScheme(.dark).environment(
        \.colorScheme, .dark
      )
      .onAppear { selected = initialSelection }
  }

  private func catalogueRow(_ title: String, subtitle: String, selection: BuildingID?) -> some View
  {
    Button {
      selected = selection
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        Text(title).fontWeight(.semibold)
        Text(subtitle).font(.system(size: 13)).foregroundStyle(GamePalette.muted)
          .fixedSize(horizontal: false, vertical: true)
      }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
        .background(
          selected == selection ? GamePalette.gold.opacity(0.22) : .clear,
          in: RoundedRectangle(cornerRadius: 5)
        )
        .contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel("\(title), \(subtitle)")
      .accessibilityAddTraits(selected == selection ? .isSelected : [])
  }

  private var landControls: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Farmland").font(.title2)
      Button("Paint farmland") { infrastructure(.farmland) }
        .disabled(Settlement.farmlandEditingProblem(state) != nil)
      Text(
        Settlement.farmlandEditingProblem(state)
          ?? "1 Galbeni per tile. Click or drag to paint any shape. Farming yields stay the same for any plot size."
      )
      Divider()
      Text("Roads & boundaries").font(.title2)
      HStack {
        Button("Stone pavement") { infrastructure(.pavement) }
        Button("Dirt path") { infrastructure(.dirtPath) }
      }
      HStack {
        Button("Rail fence") { infrastructure(.fence) }
        Button("Wattle fence") { infrastructure(.wattleFence) }
        Button("Erase") { infrastructure(.erase) }
      }
      Text(
        "1 Galbeni per tile or edge. Drag to paint; R rotates the fence edge. Erase has no refund."
      )
      .font(.system(size: 13)).foregroundStyle(GamePalette.muted)
    }.buttonStyle(.bordered)
  }
}

enum ConstructionPresentation {
  static func status(_ id: BuildingID, state: GameState) -> String {
    if let record = state.buildings.first(where: { $0.id == id }) {
      if record.level == 0 { return "Under construction" }
      return record.condition > 0
        ? "Operational · level \(record.level)" : "Needs repair · level \(record.level)"
    }
    if Construction.stage(id, state: state) == .planned {
      return "Under construction · weekly plan"
    }
    let requirements = Construction.requirements(id, state: state)
    if !requirements.locks.isEmpty { return "Locked" }
    return requirements.shortages.isEmpty ? "Ready to build" : "Missing supplies"
  }

  static func seasonEnd(_ turn: Int) -> String {
    "\(Content.seasons[turn % 4]) \(1495 + turn / 4) · Month 3 · Week 4"
  }

  static func completion(_ state: GameState) -> String {
    let turn = state.turn + (state.isSeasonEnd && state.phase != .work ? 1 : 0)
    let weeks = (turn - state.turn) * 12 + 12 - state.week - (state.phase == .work ? 0 : 1)
    return "Completes \(seasonEnd(turn)) · \(weeks) week(s)"
  }

  static func payout(_ id: BuildingID, state: GameState) -> String {
    let record = state.buildings.first { $0.id == id }
    let definition = Construction.definition(id)
    guard definition.food > 0 || definition.coins > 0 else {
      return "No seasonal payout · storage applies on completion"
    }
    guard record?.condition != 0 else { return "Next seasonal payout: repair first" }
    let earliest = state.turn + (state.isSeasonEnd && state.phase != .work ? 1 : 0)
    let completionTurn = record?.level == 0 || record == nil ? earliest : record!.completedSeason
    let turn = max(earliest, completionTurn + 1)
    let weeks = (turn - state.turn) * 12 + 12 - state.week - (state.phase == .work ? 0 : 1)
    return
      "Next payout: \(seasonEnd(turn)) · \(weeks) week(s) · \(definition.yieldText(level: max(1, record?.level ?? 1)))"
  }
}
