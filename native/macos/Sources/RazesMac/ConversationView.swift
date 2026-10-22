import RazesCore
import SwiftUI

struct ConversationView: View {
  @Bindable var session: GameSession
  let state: GameState
  var body: some View {
    let event = Rules.currentEvent(state)
    let revision = state.revision
    VStack(alignment: .leading, spacing: 16) {
      Text(event.eyebrow).font(.caption).foregroundStyle(.secondary)
      Text(event.title).font(.system(size: 30, design: .serif))
      Label(Content.shared.people[event.person]!.name, systemImage: "person.crop.circle").font(
        .headline)
      Text(event.text).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
      Divider()
      ForEach(event.choices) { choice in
        let problem = Rules.choiceProblem(state, choice: choice)
        VStack(alignment: .leading, spacing: 6) {
          Button {
            session.send(
              Action(type: "choose", revision: revision, event: event.id, choice: choice.id))
          } label: {
            VStack(alignment: .leading, spacing: 5) {
              Text(choice.label).fontWeight(.semibold)
              Text(choice.detail).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
          }.buttonStyle(.bordered).disabled(problem != nil)
          if let problem { Text(problem).font(.caption).foregroundStyle(.red) }
        }
      }
    }
  }
}
