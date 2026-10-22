import RazesCore
import SwiftUI

struct WorkView: View {
  @Bindable var session: GameSession
  var filter: TaskID? = nil
  var body: some View {
    let state = session.state
    let revision = state.revision
    VStack(alignment: .leading, spacing: 14) {
      ForEach(WorkerID.allCases, id: \.self) { worker in
        let person = Content.shared.people[worker.rawValue]!
        let reserved = state.reservedWorker == worker.rawValue
        VStack(alignment: .leading, spacing: 5) {
          HStack {
            Text(person.name).font(.headline).frame(width: 60, alignment: .leading)
            if let filter {
              Button("Assign \(Rules.task(filter).name)") {
                session.send(
                  Action(type: "assign", revision: revision, worker: worker, task: filter))
              }
              .disabled(Rules.assignmentProblem(state, worker: worker, task: filter) != nil)
            } else {
              Picker(
                "\(person.name)’s work",
                selection: Binding(
                  get: { state.assignments[worker.rawValue]! },
                  set: {
                    session.send(
                      Action(type: "assign", revision: revision, worker: worker, task: $0))
                  })
              ) {
                ForEach(Rules.taskOptions(state)) { task in
                  Text(task.name).tag(task.id).disabled(
                    !reserved
                      && Rules.assignmentProblem(state, worker: worker, task: task.id) != nil)
                }
              }.labelsHidden().disabled(reserved)
            }
          }
          if reserved {
            Text("Reserved for your promise to Vasile").font(.caption).foregroundStyle(.secondary)
          } else if let filter,
            let problem = Rules.assignmentProblem(state, worker: worker, task: filter)
          {
            Text(problem).font(.caption).foregroundStyle(.secondary)
          } else if let id = state.assignments[worker.rawValue],
            case let task = Rules.task(id)
          {
            Text(task.description).font(.caption).foregroundStyle(.secondary)
            if task.moneyCost > 0 || task.foodCost > 0 {
              Text("Cost: \(task.moneyCost) money · \(task.foodCost) food").font(.caption)
            }
          }
        }
      }
    }
  }
}
