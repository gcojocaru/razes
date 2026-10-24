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
        let task = Rules.task(Materials.assignments(state)[worker.rawValue]!)
        Button {
          choose(.worker(worker))
        } label: {
          HStack(spacing: 9) {
            PortraitView(person: worker.rawValue).frame(width: 42, height: 54)
              .overlay(Rectangle().stroke(GamePalette.gold.opacity(0.6)))
            VStack(alignment: .leading, spacing: 4) {
              Text(person.name).font(.system(size: 15, weight: .semibold, design: .serif))
              Text(state.phase == .dead ? "Deceased" : task.name)
                .font(.system(size: 11)).lineLimit(2).multilineTextAlignment(.leading)
            }.frame(maxWidth: .infinity, alignment: .leading)
          }.frame(width: 160).padding(5)
            .background(selection == .worker(worker) ? GamePalette.gold.opacity(0.20) : .clear)
        }.buttonStyle(.plain)
          .accessibilityLabel("\(person.name), \(state.phase == .dead ? "deceased" : task.name)")
          .help("Select \(person.name) to inspect needs, skills and work")
      }
      CharacterNeedsView(character: state.character).frame(width: 125)
      Divider().overlay(GamePalette.gold.opacity(0.5)).frame(height: 52)
      Button(action: build) { Label("Build", systemImage: "hammer").padding(.vertical, 8) }
        .disabled(state.phase == .dead)
        .help("Build and manage eleven structure types, each with five levels")
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
    case .work: "PLAN YOUR WORK"
    case .summary: "WEEK REPORT"
    case .dead: "ION HAS DIED"
    }
  }
  private var primaryLabel: String {
    switch state.phase {
    case .work: "End week"
    case .summary: "Review week"
    case .dead: "Final report"
    }
  }
}
