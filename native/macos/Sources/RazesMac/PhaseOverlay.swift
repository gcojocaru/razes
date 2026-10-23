import RazesCore
import SwiftUI

struct PhaseOverlay: View {
  @Bindable var session: GameSession
  let state: GameState
  let close: () -> Void
  let restart: () -> Void
  let journal: () -> Void
  @AccessibilityFocusState private var headingFocused: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(title).font(.system(size: 11, weight: .semibold)).tracking(2).foregroundStyle(
          GamePalette.gold
        )
        .accessibilityAddTraits(.isHeader).accessibilityFocused($headingFocused)
        Spacer()
        if state.phase != .opening && state.phase != .consequence {
          Button("Close", systemImage: "xmark", action: close).labelStyle(.iconOnly)
            .help(
              "Close review")
        }
      }
      switch state.phase {
      case .opening, .consequence: ConversationView(session: session, state: state)
      case .work:
        let forecast = Rules.preview(state)
        HStack(alignment: .top, spacing: 24) {
          VStack(alignment: .leading, spacing: 8) {
            Text("A season’s work").font(.system(size: 26, design: .serif))
            ForEach(WorkerID.allCases, id: \.self) { worker in
              Text(
                "\(Content.shared.people[worker.rawValue]!.name): \(Rules.task(state.assignments[worker.rawValue]!).name)"
              ).font(.callout)
            }
            Text("Work costs: \(forecast.moneyCost) money · \(forecast.foodCost) food").font(
              .caption
            ).foregroundStyle(GamePalette.gold)
            if Materials.reserved(state).total > 0 {
              Text("Building supplies: \(Materials.reserved(state).text)").font(.caption)
            }
            ForEach(Materials.forecast(state).lines, id: \.self) { Text($0).font(.caption) }
          }.frame(maxWidth: .infinity, alignment: .leading)
          VStack(alignment: .leading, spacing: 8) {
            Text("AFTER WORK & CONSUMPTION").font(.system(size: 10, weight: .semibold)).tracking(1)
            Text(
              "Food \(forecast.foodAfter) · Money \(forecast.moneyAfter) · Shelter \(forecast.houseAfter)"
            ).font(.headline)
            Text("The evening conversation may change the outcome.").font(.caption).foregroundStyle(
              GamePalette.muted)
            ForEach(forecast.errors, id: \.self) {
              Text($0).font(.caption).foregroundStyle(.orange)
            }
            ForEach(forecast.warnings, id: \.self) {
              Text($0).font(.caption).foregroundStyle(GamePalette.gold)
            }
            Button("Confirm season’s work") {
              session.send(Action(type: "resolve", revision: state.revision))
            }.buttonStyle(.borderedProminent).disabled(!forecast.errors.isEmpty)
          }.frame(maxWidth: .infinity, alignment: .leading)
        }
      case .summary:
        Text("\(Content.seasons[state.season]), remembered").font(.system(size: 27, design: .serif))
        if let report = state.report {
          HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
              ForEach(report.tasks, id: \.self) { Text($0).font(.callout) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
              Text(
                "Food \(report.foodBefore) → \(report.foodAfter) · Money \(report.moneyBefore) → \(report.moneyAfter)"
              )
              Text("Shelter \(report.houseBefore) → \(report.houseAfter)")
              if let haul = state.lastMaterialHaul {
                Text("Gathered: \(haul.text)").font(.caption)
              }
              Text("Consumed \(report.consumption) food · Weathering \(report.wear)").font(.caption)
                .foregroundStyle(GamePalette.muted)
              if report.deficit > 0 {
                Text("Food shortfall: \(report.deficit). Recorded as hardship.").foregroundStyle(
                  .orange
                ).font(.caption)
              }
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        Button(
          state.season == 3
            ? "See what the year has meant"
            : "Continue to \(Content.seasons[min(3,state.season+1)])"
        ) { session.send(Action(type: "continue", revision: state.revision)) }.buttonStyle(
          .borderedProminent)
      case .ending:
        let ending = Rules.ending(state)
        Text(ending.title).font(.system(size: 27, design: .serif))
        Text(ending.text).lineSpacing(3)
        HStack(alignment: .top, spacing: 20) {
          ForEach(ending.decisions, id: \.event) { decision in
            VStack(alignment: .leading, spacing: 5) {
              Text(decision.title).font(.headline)
              Text(decision.detail).font(.caption).foregroundStyle(GamePalette.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        HStack {
          Button("Next settlement season") {
            session.send(.init(type: "settlement", revision: state.revision))
          }
          Button("Promise journal", action: journal)
          Button("Begin another household", action: restart).buttonStyle(.borderedProminent)
        }
        ForEach(Materials.forecast(state).lines, id: \.self) { Text($0).font(.caption) }
        if let haul = state.lastMaterialHaul { Text("Last haul: \(haul.text)").font(.caption) }
        Text("Use Materials or a portrait to assign gathering for the next settlement season.").font(.caption)
      }
    }.onAppear { headingFocused = true }
  }
  private var title: String {
    switch state.phase {
    case .opening: "A CONVERSATION"
    case .work: "REVIEW & CONFIRM"
    case .consequence: "AS EVENING FALLS"
    case .summary: "SEASON REMEMBERED"
    case .ending: "YOUR FIRST YEAR"
    }
  }
}
