import RazesCore
import SwiftUI

struct PhaseOverlay: View {
  @Bindable var session: GameSession
  let state: GameState
  let close: () -> Void
  var restart: () -> Void = {}
  @AccessibilityFocusState private var headingFocused: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(title).font(.system(size: 11, weight: .semibold)).tracking(2).foregroundStyle(
          GamePalette.gold
        )
        .accessibilityAddTraits(.isHeader).accessibilityFocused($headingFocused)
        Spacer()
        Button("Close", systemImage: "xmark", action: close).labelStyle(.iconOnly)
          .help("Close review")
      }
      switch state.phase {
      case .work:
        let forecast = Rules.preview(state)
        HStack(alignment: .top, spacing: 24) {
          VStack(alignment: .leading, spacing: 8) {
            Text("A week’s work").font(.system(size: 26, design: .serif))
            ForEach(WorkerID.allCases, id: \.self) { worker in
              Text(
                "\(Content.shared.people[worker.rawValue]!.name): \(Rules.task(state.assignments[worker.rawValue]!).name)"
              ).font(.callout)
            }
            Text("Work costs: \(forecast.moneyCost) money · \(forecast.foodCost) food").font(
              .caption
            ).foregroundStyle(GamePalette.gold)
            Text(
              "Seeds: \(state.seeds) → \(forecast.seedsAfter) · sowing uses \(forecast.seedCost) · harvest returns \(forecast.seedGain)"
            )
            .font(.caption).foregroundStyle(GamePalette.gold)
            Text(Rules.fieldLabel(state)).font(.caption)
            if Materials.reserved(state).total > 0 {
              Text("Building supplies: \(Materials.reserved(state).text)").font(.caption)
            }
            ForEach(Materials.forecast(state).lines, id: \.self) { Text($0).font(.caption) }
            Divider()
            CharacterWeekView(week: forecast.character)
          }.frame(maxWidth: .infinity, alignment: .leading)
          VStack(alignment: .leading, spacing: 8) {
            Text(
              "This week’s meal: \(forecast.consumption) food · Seasonal wear: \(forecast.wear)"
            )
            .font(.caption).foregroundStyle(GamePalette.muted)
            Text("AFTER WORK & CONSUMPTION").font(.system(size: 10, weight: .semibold)).tracking(1)
            Text(
              "Food \(forecast.foodAfter) · Money \(forecast.moneyAfter) · Shelter \(forecast.houseAfter)"
            ).font(.headline)
            ForEach(forecast.errors, id: \.self) {
              Text($0).font(.caption).foregroundStyle(.orange)
            }
            ForEach(forecast.warnings, id: \.self) {
              Text($0).font(.caption).foregroundStyle(GamePalette.gold)
            }
            Button(forecast.character.fatal ? "Confirm fatal week" : "Confirm week’s work") {
              session.send(Action(type: "resolve", revision: state.revision))
            }.buttonStyle(.borderedProminent).disabled(!forecast.errors.isEmpty)
          }.frame(maxWidth: .infinity, alignment: .leading)
        }
      case .summary, .dead:
        if state.phase == .dead {
          Text("Ion has died").font(.system(size: 27, design: .serif))
          Text("\(state.report?.character.deathCause ?? "Death") · \(state.calendarLabel)")
            .foregroundStyle(.orange)
        }
        Text("Month \(state.month) · Week \(state.weekOfMonth) report").font(
          .system(size: 27, design: .serif))
        if let report = state.report {
          HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
              ForEach(report.tasks, id: \.self) { Text($0).font(.callout) }
              CharacterWeekView(week: report.character)
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
              Text(
                "Food \(report.foodBefore) → \(report.foodAfter) · Money \(report.moneyBefore) → \(report.moneyAfter)"
              )
              Text("Seeds \(report.seedsBefore) → \(report.seedsAfter)")
              Text("Shelter \(report.houseBefore) → \(report.houseAfter)")
              if let haul = state.lastMaterialHaul {
                Text("Gathered: \(haul.text)").font(.caption)
              }
              Text("Consumed \(report.consumption) food · Weathering \(report.wear)").font(.caption)
                .foregroundStyle(GamePalette.muted)
              if report.deficit > 0 {
                Text("Food shortfall: \(report.deficit).").foregroundStyle(
                  .orange
                ).font(.caption)
              }
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        if state.phase == .dead {
          Button("Start a fresh household", action: restart).buttonStyle(.borderedProminent)
        } else {
          Button("Continue to \(state.nextWeekLabel)") {
            session.send(Action(type: "continue", revision: state.revision))
          }.buttonStyle(.borderedProminent)
        }
      }
    }.onAppear { headingFocused = true }
  }
  private var title: String {
    switch state.phase {
    case .work: "REVIEW & CONFIRM"
    case .summary: "WEEK REPORT"
    case .dead: "FINAL REPORT"
    }
  }
}
