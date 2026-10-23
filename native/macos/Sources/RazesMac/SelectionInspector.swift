import RazesCore
import SwiftUI

struct SelectionInspector: View {
  @Bindable var session: GameSession
  let state: GameState
  let selection: SceneSelection
  let beginPlacement: (PlacementTool) -> Void
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
        if state.phase == .work || state.phase == .ending {
          if state.phase == .work && state.reservedWorker == worker.rawValue {
            Text("Reserved for your promise to Vasile.").foregroundStyle(GamePalette.gold)
          } else {
            ForEach(Rules.taskOptions(state).filter { Construction.building(for: $0.id) == nil }) {
              task in
              let reason = Rules.assignmentProblem(state, worker: worker, task: task.id)
              Button {
                if let id = Construction.building(for: task.id),
                  Settlement.position(for: id, in: state.layout) == nil
                {
                  beginPlacement(.building(id, worker: worker, instant: false))
                } else {
                  session.send(
                    Action(type: "assign", revision: state.revision, worker: worker, task: task.id))
                }
              } label: {
                HStack {
                  Text(task.name)
                  Spacer()
                  if task.id == Materials.assignments(state)[worker.rawValue] {
                    Image(systemName: "checkmark")
                  }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
              }.disabled(reason != nil).help(reason ?? task.description)
              if let reason { Text(reason).font(.caption).foregroundStyle(GamePalette.muted) }
            }
            let task = Rules.task(Materials.assignments(state)[worker.rawValue]!)
            Text(task.description).font(.caption).foregroundStyle(GamePalette.muted)
            Text("Current work cost: \(task.moneyCost) money · \(task.foodCost) food").font(
              .caption)
          }
        } else {
          Text("Assign work after the opening conversation.").font(.caption)
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
          Text(Rules.fieldLabel(state)).font(.callout)
          if let task = Rules.taskOptions(state).first(where: {
            [TaskID.plant, .tend, .harvest].contains($0.id)
          }) {
            Text(task.description).font(.caption)
            assignmentButtons(task.id)
          } else {
            Text("No field work is available this season.").font(.caption)
          }
        case .visitor:
          Text("Your neighbours remember the work and the promises you share.").font(.callout)
        }
      }
    }.buttonStyle(.bordered).controlSize(.regular)
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
