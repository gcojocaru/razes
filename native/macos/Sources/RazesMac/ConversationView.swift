import RazesCore
import SwiftUI

struct ConversationView: View {
  @Bindable var session: GameSession
  let state: GameState
  var body: some View {
    let event = Rules.currentEvent(state)
    let revision = state.revision
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 16) {
        PortraitView(person: event.person).frame(width: 70, height: 88)
          .overlay(Rectangle().stroke(GamePalette.gold.opacity(0.6)))
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .firstTextBaseline) {
            Text(event.title).font(.system(size: 27, design: .serif))
            Spacer()
            Text(Content.shared.people[event.person]!.name).font(.caption).foregroundStyle(
              GamePalette.gold)
          }
          Text(event.text).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
      }
      HStack(alignment: .top, spacing: 10) {
        ForEach(event.choices) { choice in
          let problem = Rules.choiceProblem(state, choice: choice)
          VStack(alignment: .leading, spacing: 5) {
            Button {
              session.send(
                Action(type: "choose", revision: revision, event: event.id, choice: choice.id))
            } label: {
              VStack(alignment: .leading, spacing: 6) {
                Text(choice.label).fontWeight(.semibold).lineLimit(nil).fixedSize(
                  horizontal: false, vertical: true)
                Text(choice.detail).font(.caption).foregroundStyle(GamePalette.muted).lineLimit(nil)
                  .fixedSize(horizontal: false, vertical: true)
              }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 7)
            }.buttonStyle(.bordered).disabled(problem != nil)
            if let problem { Text(problem).font(.caption).foregroundStyle(.orange) }
          }.frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }
}
