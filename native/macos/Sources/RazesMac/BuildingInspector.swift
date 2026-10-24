import AppKit
import RazesCore
import SwiftUI

struct BuildingInspector: View {
  @Bindable var session: GameSession
  let state: GameState
  let id: BuildingID
  let beginPlacement: (PlacementTool) -> Void
  var body: some View {
    let definition = Construction.definition(id)
    let record = state.buildings.first { $0.id == id }
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 16) {
        BuildingThumbnail(
          id: id, winter: state.displaySeason == 3, level: max(1, record?.level ?? 1)
        ).frame(width: 110, height: 100)
        VStack(alignment: .leading, spacing: 8) {
          Text(definition.title).font(.system(size: 25, design: .serif))
          Text(ConstructionPresentation.status(id, state: state)).fontWeight(.semibold)
            .foregroundStyle(GamePalette.gold)
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
      Text(Construction.practicalBenefit(id, level: max(1, record?.level ?? 1)))
      Text(ConstructionPresentation.payout(id, state: state))
        .font(.system(size: 13)).foregroundStyle(GamePalette.muted)
      if id == .workshop {
        Divider()
        WorkshopCraftingControls(session: session, state: state)
      }
      if let record {
        if record.level == 0 {
          Text(ConstructionPresentation.completion(state))
          Text(
            "Ion keeps his weekly assignment. Practical benefits begin on completion; seasonal income begins the following season."
          )
          .font(.system(size: 13))
        } else {
          if record.condition == 0 && id != .storehouse {
            Text("Practical benefits and seasonal income resume after repair.")
              .font(.system(size: 13)).foregroundStyle(GamePalette.gold)
          }
          Text("Condition: \(Int(record.condition))%")
          ProgressView(value: record.condition, total: 100).accessibilityLabel("Building condition")
          if record.level < 5 {
            Divider()
            Text("Upgrade to level \(record.level + 1)").fontWeight(.semibold)
            let requirements = Construction.requirements(id, state: state, level: record.level + 1)
            ConstructionRequirementTable(requirements: requirements, state: state)
            Text(Construction.practicalBenefit(id, level: record.level + 1)).font(.system(size: 13))
            if id != .storehouse {
              Text("After upgrade: \(definition.yieldText(level: record.level + 1))")
                .font(.system(size: 13)).foregroundStyle(GamePalette.gold)
            }
            Button("Upgrade · immediate") { session.upgradeBuilding(id) }.disabled(
              !requirements.isMet)
          } else {
            Label("Maximum level reached", systemImage: "checkmark.seal")
          }
          Divider()
          let requirements = Construction.repairRequirements(id, state: state)
          if record.condition < 100 {
            Text("Repair to 100% condition").fontWeight(.semibold)
            ConstructionRequirementTable(
              requirements: requirements, state: state, progression: false)
            Button("Repair · immediate") { session.repairBuilding(id) }
              .disabled(!requirements.isMet)
          } else {
            Text("Repair when worn: \(requirements.coins) Galbeni · \(requirements.materials.text)")
              .font(.system(size: 13))
          }
          Text(
            "Wear: 20 condition per season. At zero, level 2–5 loses a level and returns to 60 condition; level 1 needs repair."
          )
          .font(.system(size: 13)).foregroundStyle(GamePalette.muted)
        }
      } else if Construction.stage(id, state: state) == .planned {
        Text("Ion places the foundation when this week resolves. It completes at season end.")
        Text(ConstructionPresentation.completion(state))
        Button("Remove weekly plan") { session.removePlan(id) }
      } else {
        Text(ConstructionPresentation.completion(state))
        let requirements = Construction.requirements(id, state: state)
        ConstructionRequirementTable(requirements: requirements, state: state)
        Button("Choose building location") {
          beginPlacement(.building(id, worker: nil, instant: false))
        }
        .disabled(!requirements.isMet)
      }
      if let position = Settlement.position(for: id, in: state.layout) {
        Divider()
        Text("Plot: \(position.x), \(position.y)").font(.system(size: 13))
        HStack {
          Button("Rotate 90°") { session.rotateBuilding(id) }
          Button("Move plot") { beginPlacement(.building(id, worker: nil, instant: false)) }
        }
      }
      if let error = session.error { Text(error).foregroundStyle(.orange) }
    }.font(.system(size: 14)).buttonStyle(.bordered).disabled(state.phase == .dead)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct ConstructionRequirementTable: View {
  let requirements: ConstructionRequirements
  let state: GameState
  var progression = true
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Requirements").fontWeight(.semibold)
      Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 7) {
        GridRow {
          Text("Required")
          Text("Need")
          Text("Free")
          Text("Missing")
        }.fontWeight(.semibold)
        if progression {
          row("House level", need: requirements.houseLevel, free: state.houseLevel)
          if requirements.buildingLevel > 0 {
            row(
              "Building skill", need: requirements.buildingLevel,
              free: state.character.level(.building))
          }
          if let prerequisite = requirements.prerequisite {
            let complete = state.buildings.contains { $0.id == prerequisite && $0.level > 0 }
            GridRow {
              Text(Construction.definition(prerequisite).title)
              Text("Built")
              Text(complete ? "Built" : "—")
              Text(complete ? "—" : "Build first")
            }
          }
        }
        row("Galbeni", need: requirements.coins, free: requirements.freeCoins)
        ForEach(MaterialID.allCases, id: \.self) { material in
          row(
            material.title, need: requirements.materials[material],
            free: requirements.freeMaterials[material])
        }
      }.font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
      ForEach(requirements.problems, id: \.self) { problem in
        Label(problem, systemImage: "exclamationmark.circle").foregroundStyle(GamePalette.gold)
          .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
      }
    }.padding(12).background(GamePalette.ink, in: RoundedRectangle(cornerRadius: 5))
  }
  private func row(_ title: String, need: Int, free: Int) -> some View {
    GridRow {
      Text(title)
      Text("\(need)")
      Text("\(free)")
      Text(need > free ? "\(need - free)" : "—").foregroundStyle(
        need > free ? GamePalette.gold : GamePalette.muted)
    }.accessibilityElement(children: .combine)
  }
}

struct WorkshopCraftingControls: View {
  @Bindable var session: GameSession
  let state: GameState
  @State private var quantity = 1
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Workshop · craft planks").fontWeight(.semibold)
      Text("\(Materials.plankWoodCost(state: state)) wood → 1 plank · immediate · no worker or XP")
        .font(.system(size: 13))
      Text(
        "Free wood: \(Materials.available(state).wood) · material storage: \(state.materials.total)/\(Materials.capacity(state))"
      )
      .font(.system(size: 13)).foregroundStyle(GamePalette.muted)
      Stepper("Planks: \(quantity)", value: $quantity, in: 1...100)
      let problems = Materials.craftingProblems(quantity: quantity, state: state)
      Button("Craft \(quantity) planks · \(quantity * Materials.plankWoodCost(state: state)) wood")
      {
        session.craftPlanks(quantity: quantity)
      }.disabled(!problems.isEmpty)
      ForEach(problems, id: \.self) {
        Text($0).font(.system(size: 13)).foregroundStyle(GamePalette.gold)
      }
    }
  }
}

struct HouseConstructionDetail: View {
  @Bindable var session: GameSession
  let state: GameState
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 16) {
        BuildingThumbnail(
          id: nil, winter: state.displaySeason == 3, level: state.houseLevel,
          damaged: state.house < 65
        ).frame(width: 110, height: 100)
        Text("House · level \(state.houseLevel)/5").font(.system(size: 25, design: .serif))
      }
      Text(
        "\(20 + (state.houseLevel - 1) * 10) shared material slots. House level opens more building blueprints and upgrades."
      )
      if state.houseLevel < 5 {
        Text("Upgrade to level \(state.houseLevel + 1) · +10 storage slots").fontWeight(.semibold)
        ConstructionRequirementTable(
          requirements: Materials.houseUpgradeRequirements(state: state), state: state,
          progression: false)
        Text(
          "Immediate · no Building skill required. Level 2 adds a timber porch, plaster and a stone foundation."
        )
        .font(.system(size: 13))
        Button("Upgrade house") { session.upgradeHouseStorage() }
          .disabled(!Materials.houseUpgradeRequirements(state: state).isMet)
      } else {
        Label("Maximum level reached", systemImage: "checkmark.seal")
      }
      if let error = session.error { Text(error).foregroundStyle(.orange) }
    }.font(.system(size: 14)).buttonStyle(.bordered).disabled(state.phase == .dead)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct BuildingThumbnail: View {
  let id: BuildingID?
  let winter: Bool
  var level = 1
  var damaged = false
  private var artwork: NSImage? {
    if let id {
      return HomesteadScene.buildingArtworkImage(
        id, level: level, planned: false, winter: winter, facing: 0)
    }
    return HomesteadScene.houseArtworkImage(
      level: level, damaged: damaged, winter: winter, facing: 0)
  }
  var body: some View {
    Group {
      if let artwork {
        Image(nsImage: artwork).resizable().scaledToFit()
      } else {
        Image(systemName: "house").resizable().scaledToFit().padding(20)
      }
    }.accessibilityHidden(true)
  }
}
