import RazesCore
import SwiftUI

struct GameHUD: View {
  let state: GameState
  let selection: SceneSelection?
  let buildMode: Bool
  let choose: (SceneSelection) -> Void
  let build: () -> Void
  let primary: () -> Void
  var body: some View {
    HStack(spacing: 10) {
      ForEach(WorkerID.allCases, id: \.self) { worker in
        let person = Content.shared.people[worker.rawValue]!
        let task = Rules.task(state.assignments[worker.rawValue]!)
        Button {
          choose(.worker(worker))
        } label: {
          HStack(spacing: 9) {
            PortraitView(person: worker.rawValue).frame(width: 42, height: 54)
              .overlay(Rectangle().stroke(GamePalette.gold.opacity(0.6)))
            VStack(alignment: .leading, spacing: 4) {
              Text(person.name).font(.system(size: 15, weight: .semibold, design: .serif))
              Text(state.reservedWorker == worker.rawValue ? "Promised to Vasile" : task.name)
                .font(.system(size: 11)).lineLimit(2).multilineTextAlignment(.leading)
            }.frame(maxWidth: .infinity, alignment: .leading)
          }.frame(width: 160).padding(5)
            .background(selection == .worker(worker) ? GamePalette.gold.opacity(0.20) : .clear)
        }.buttonStyle(.plain).accessibilityLabel("\(person.name), \(task.name)")
          .help("Select \(person.name) and assign work")
      }
      Divider().overlay(GamePalette.gold.opacity(0.5)).frame(height: 52)
      Button(action: build) { Label("Build", systemImage: "hammer").padding(.vertical, 8) }
        .disabled(state.phase != .work).help("Plan a woodshed or root cellar")
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 7) {
        Text(phaseLabel).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(
          GamePalette.muted)
        Button(primaryLabel, action: primary).buttonStyle(.borderedProminent).controlSize(.large)
      }
    }.padding(.horizontal, 18).padding(.vertical, 12)
      .frame(height: 96).foregroundStyle(GamePalette.paper)
      .background(GamePalette.panel.opacity(0.96))
      .overlay(alignment: .top) { Rectangle().fill(GamePalette.gold.opacity(0.7)).frame(height: 1) }
  }
  private var phaseLabel: String {
    switch state.phase {
    case .opening: "A CONVERSATION"
    case .work: "PLAN YOUR WORK"
    case .consequence: "AS EVENING FALLS"
    case .summary: "SEASON REMEMBERED"
    case .ending: "YOUR FIRST YEAR"
    }
  }
  private var primaryLabel: String {
    switch state.phase {
    case .opening, .consequence: "Conversation"
    case .work: "End season"
    case .summary: "Review season"
    case .ending: "Review year"
    }
  }
}
