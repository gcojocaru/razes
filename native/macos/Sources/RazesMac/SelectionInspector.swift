import RazesCore
import SwiftUI

struct SelectionInspector: View {
  @Bindable var session: GameSession
  let state: GameState
  let selection: SceneSelection
  let beginPlacement: (PlacementTool) -> Void
  let buySupplies: () -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      switch selection {
      case .worker(let worker):
        let person = Content.shared.people[worker.rawValue]!
        HStack {
          PortraitView(person: worker.rawValue).frame(width: 48, height: 60)
          VStack(alignment: .leading, spacing: 4) {
            Text(person.name).font(.system(size: 25, design: .serif))
            Text(person.role).font(.caption).foregroundStyle(GamePalette.muted)
          }
        }
        Text(person.line).font(.callout).italic()
        if state.phase == .work {
          Button("Rest · recover energy and health") {
            session.send(
              .init(type: "assign", revision: state.revision, worker: worker, task: .rest))
          }
          let current = state.assignments[worker.rawValue] ?? .rest
          Text(
            "Current assignment: \(Rules.task(current).name) · \(CharacterSimulation.energyCost(current, character: state.character)) energy"
          )
          .font(.caption).foregroundStyle(GamePalette.gold)
        } else if state.phase == .dead {
          Text("Ion has died. Open the final report to begin a fresh household.")
            .foregroundStyle(.orange)
        }
        CharacterSkillsView(character: state.character)
        Divider()
        PlantingControls(session: session, state: state)
        if state.phase == .work {
          ForEach(
            Rules.taskOptions(state).filter {
              $0.id != .plant && $0.id != .rest && Construction.building(for: $0.id) == nil
            }
          ) {
            task in
            let reason = Rules.assignmentProblem(state, worker: worker, task: task.id)
            Button {
              session.send(
                Action(type: "assign", revision: state.revision, worker: worker, task: task.id))
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(task.name)
                  Text(
                    "\(CharacterSimulation.energyCost(task.id, character: state.character)) energy"
                  )
                  .font(.caption).foregroundStyle(GamePalette.muted)
                }
                Spacer()
                if task.id == Materials.assignments(state)[worker.rawValue] {
                  Image(systemName: "checkmark")
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }.disabled(reason != nil).help(reason ?? task.description)
            if let reason { Text(reason).font(.caption).foregroundStyle(GamePalette.muted) }
          }
          let task = Rules.task(Materials.assignments(state)[worker.rawValue]!, in: state)
          Text(task.description).font(.caption).foregroundStyle(GamePalette.muted)
          Text(
            "Current work cost: \(task.moneyCost) money · \(task.foodCost) food · \(task.id == .plant ? Farming.seedCost : 0) seeds"
          ).font(
            .caption)
        } else if state.phase != .dead {
          Text("Continue to the next week to assign work.").font(.caption)
        }
      case .building(let id):
        BuildingInspector(session: session, state: state, id: id, beginPlacement: beginPlacement)
      case .scenery(let id):
        if let scenery = state.layout.scenery.first(where: { $0.id == id }) {
          Text(scenery.kind.rawValue.capitalized).font(.system(size: 25, design: .serif))
          Text("Debug scenery · no resource bonus").font(.caption).foregroundStyle(
            GamePalette.muted)
          Text("Position: \(scenery.position.x), \(scenery.position.y)")
          Button("Rotate scenery 90°") { session.rotateScenery(id) }
          Button("Remove scenery") { session.removeScenery(id) }
        }
      case .hotspot(let spot):
        Text(spot.rawValue.capitalized).font(.system(size: 25, design: .serif))
        switch spot {
        case .house:
          HouseStockOverview(state: state)
          Button("Buy supplies", systemImage: "cart", action: buySupplies)
          Divider()
          Text("Shelter: \(state.house)/100")
          HouseStorageControls(session: session, state: state)
          Text(
            "Winter wear: \(Construction.active(.woodshed, state: state) ? 6:14). Keep the roof ready for the cold."
          ).font(.caption)
          assignmentButtons(.repair)
        case .stores:
          Text("\(state.food) food · \(state.money) money")
          Text("A provisions purchase brings \(Rules.suppliesGain(state)) food for 4 money.").font(
            .caption)
          assignmentButtons(.supplies)
        case .field:
          Text("\(state.layout.farmland.count) farmland tiles").font(.headline)
          Text(Rules.fieldLabel(state)).font(.callout)
          PlantingControls(session: session, state: state)
          Button("Paint farmland") { beginPlacement(.infrastructure(.farmland)) }
            .disabled(Settlement.farmlandEditingProblem(state) != nil)
          if let reason = Settlement.farmlandEditingProblem(state) {
            Text(reason).font(.caption).foregroundStyle(GamePalette.muted)
          }
          Text("Grain seeds: \(state.seeds) · sowing needs \(Farming.seedCost)").font(.caption)
          Button("Buy 4 grain seeds · 4 coins") { session.buySeeds(quantity: 4) }
            .disabled(
              state.money - (state.phase == .work ? Rules.preview(state).moneyCost : 0) < 4
                || state.seeds > 99996)
          if state.planted && state.season != 3 && !state.harvested {
            ProgressView(value: Double(state.cropWeeks), total: Double(Farming.growingWeeks))
              .accessibilityLabel("Grain growth")
              .accessibilityValue("\(state.cropWeeks) of 24 growing weeks")
            Text(
              "Expected harvest: \(Farming.foodYield(state)) food + \(Farming.seedYield(state)) seeds"
            )
            .font(.caption).foregroundStyle(GamePalette.gold)
            Text(
              state.tended
                ? "Tended · bonus secured"
                : "Tend once after week 4 of growth, before ripening, for +8 food and +2 seeds."
            )
            .font(.caption)
          }
          if let task = Rules.taskOptions(state).first(where: {
            [TaskID.tend, .harvest].contains($0.id)
          }) {
            Text(task.description).font(.caption)
            assignmentButtons(task.id)
          }
        }
      }
    }.buttonStyle(.bordered).controlSize(.regular).disabled(state.phase == .dead)
  }
  @ViewBuilder private func assignmentButtons(_ task: TaskID) -> some View {
    if state.phase == .work {
      ForEach(WorkerID.allCases, id: \.self) { worker in
        let assigned = state.assignments[worker.rawValue] == task
        let target: TaskID = assigned ? .rest : task
        let reason = Rules.assignmentProblem(state, worker: worker, task: target)
        VStack(alignment: .leading, spacing: 4) {
          Button("\(assigned ? "Cancel":"Assign") \(Content.shared.people[worker.rawValue]!.name)")
          {
            session.send(
              Action(type: "assign", revision: state.revision, worker: worker, task: target))
          }.disabled(reason != nil)
          if let reason { Text(reason).font(.caption).foregroundStyle(GamePalette.muted) }
        }
      }
    } else {
      Text("Work commands are available during planning.").font(.caption).foregroundStyle(
        GamePalette.muted)
    }
  }
}

private struct PlantingControls: View {
  @Bindable var session: GameSession
  let state: GameState

  var body: some View {
    let assigned = state.phase == .work && state.assignments["ion"] == .plant
    let reason = Rules.assignmentProblem(state, worker: .ion, task: .plant)
    VStack(alignment: .leading, spacing: 7) {
      Label("Planting: Spring only", systemImage: "calendar")
        .font(.headline).foregroundStyle(GamePalette.gold)
      Text("All 12 spring weeks · once per year · 4 grain seeds")
        .font(.caption).foregroundStyle(GamePalette.muted)
      Text(
        assigned
          ? "Sowing assigned. Choose End week, then Confirm week’s work to plant."
          : reason
            ?? (state.isSeasonEnd
              ? "Ready to plant — this is the last week of Spring."
              : "Ready to plant — \(12 - state.week) spring weeks left.")
      )
      .font(.caption)
      .foregroundStyle(reason == nil || assigned ? GamePalette.gold : GamePalette.muted)
      Button(assigned ? "Cancel sowing" : "Plant seeds · assign Ion") {
        session.send(
          .init(
            type: "assign", revision: state.revision, worker: .ion,
            task: assigned ? .rest : .plant))
      }.disabled(!assigned && reason != nil)
    }
  }
}
