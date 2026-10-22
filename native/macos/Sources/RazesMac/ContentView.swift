import RazesCore
import SpriteKit
import SwiftUI

private let ink = Color(red: 0.18, green: 0.24, blue: 0.17)
private let parchment = Color(red: 0.97, green: 0.95, blue: 0.90)
struct ContentView: View {
  @Bindable var session: GameSession
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var scene = HomesteadScene()
  @State private var resourceWarning: String?
  @State private var sheet: String?
  @State private var restart = false
  @State private var confirmWork = false
  @State private var selectedTask: TaskID?
  @AccessibilityFocusState private var panelFocused: Bool
  private var state: GameState { session.state }
  private var reduced: Bool { systemReduceMotion || session.reduceMotion }
  var body: some View {
    VStack(spacing: 0) {
      topbar
      Divider()
      if session.needsRecovery {
        recovery.padding(40)
        Spacer()
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            heading
            if let warning = session.storageWarning {
              banner(warning, symbol: "externaldrive.badge.exclamationmark")
            }
            if let error = session.error { banner(error, symbol: "exclamationmark.triangle") }
            resources
            HStack(alignment: .top, spacing: 24) {
              VStack(alignment: .leading, spacing: 16) {
                SpriteView(scene: scene, preferredFramesPerSecond: 30)
                  .aspectRatio(1200 / 760, contentMode: .fit)
                  .clipShape(RoundedRectangle(cornerRadius: 14))
                  .accessibilityHidden(true)
                if let warning = resourceWarning { banner(warning, symbol: "photo") }
                HStack {
                  ForEach(Hotspot.allCases, id: \.rawValue) { spot in
                    Button(spot.rawValue.capitalized) { hotspot(spot) }.buttonStyle(.bordered)
                  }
                  Spacer()
                  Text(Rules.fieldLabel(state)).font(.caption).foregroundStyle(.secondary)
                }
                commitment
                household
              }.frame(maxWidth: .infinity)
              phasePanel.frame(width: 340, alignment: .leading)
            }
            HStack {
              Text("A small life. A lasting story.")
              Spacer()
              Text("Northern Moldavia · 1495 · A fictional household")
            }
            .font(.caption).foregroundStyle(.secondary)
          }.padding(28)
        }
      }
    }
    .font(.custom("DMSans9pt-Regular", size: 14, relativeTo: .body))
    .foregroundStyle(ink).background(parchment).tint(ink)
    .frame(minWidth: 1000, minHeight: 700)
    .sheet(item: Binding(get: { sheet.map(SheetID.init) }, set: { sheet = $0?.id })) { value in
      VStack(alignment: .leading, spacing: 18) {
        HStack {
          Text(
            value.id == "journal"
              ? "The promise journal" : value.id == "help" ? "How to play" : "Household work"
          ).font(.system(size: 30, design: .serif))
          Spacer()
          Button("Done") { sheet = nil }.keyboardShortcut(.cancelAction)
        }
        ScrollView {
          if value.id == "journal" {
            JournalView(state: state)
          } else if value.id == "help" {
            Text(
              "Read the seasonal conversation and choose a response. Assign one task to each adult, review the forecast, then confirm the work. An evening conversation follows before food consumption and weathering. Continue through winter to see your household’s ending.\n\nHarvest needs two adults. Honouring the borrowed ox promise reserves Petru’s autumn assignment. Every accepted choice and draft assignment saves on this Mac.\n\nScene hotspots have matching buttons. Tab moves between controls; Escape closes this window."
            ).lineSpacing(6)
          } else if let id = selectedTask, case let task = Rules.task(id) {
            Text(task.name).font(.title2)
            Text(task.description)
            Text(
              "Cost: \(task.moneyCost) money · \(task.foodCost) food. Needs \(task.workers) adult\(task.workers == 1 ? "" : "s")."
            ).padding(.vertical)
            if state.phase == .work { WorkView(session: session, filter: id) }
          }
        }
      }.padding(26).frame(width: 580, height: 480).background(parchment)
    }
    .alert("Begin a fresh household?", isPresented: $restart) {
      Button("Cancel", role: .cancel) {}
      Button("Start fresh", role: .destructive) { session.startFresh() }
    } message: {
      Text("Your existing save will be kept as a recovery copy before the new year begins.")
    }
    .alert("Confirm this season’s work?", isPresented: $confirmWork) {
      Button("Keep planning", role: .cancel) {}
      Button("Complete work") { session.send(Action(type: "resolve", revision: state.revision)) }
    } message: {
      Text(
        "Assignments become final. The evening conversation follows before consumption and weathering."
      )
    }
    .onAppear {
      scene.onHotspot = hotspot
      refreshScene()
    }
    .onChange(of: state) { old, new in
      refreshScene()
      if old.phase != new.phase { panelFocused = true }
    }
    .onChange(of: reduced) { refreshScene() }
    .onChange(of: scenePhase) { session.active = scenePhase == .active }
  }
  private var topbar: some View {
    HStack(spacing: 20) {
      Image(systemName: "leaf.fill").font(.title2)
      VStack(alignment: .leading, spacing: 0) {
        Text("Răzeș").font(.system(size: 28, design: .serif))
        Text("A HOME WORTH KEEPING").font(.system(size: 8, weight: .semibold)).tracking(2)
      }
      Spacer()
      Button("Journal", systemImage: "book") { sheet = "journal" }.keyboardShortcut(
        "j", modifiers: .command)
      Button("How to play", systemImage: "questionmark.circle") { sheet = "help" }
      Text(
        session.storageWarning != nil || session.needsRecovery
          ? "Saving unavailable" : session.hasSaved ? "Saved on this Mac" : "A new household"
      ).font(.caption).foregroundStyle(.secondary)
      Toggle(isOn: $session.soundEnabled) {
        Image(systemName: session.soundEnabled ? "speaker.wave.2" : "speaker.slash")
      }.toggleStyle(.button).accessibilityLabel("Ambient sound").help("Enable ambient sound")
      Toggle(isOn: $session.reduceMotion) { Image(systemName: "sparkles") }.toggleStyle(.button)
        .accessibilityLabel("Reduce motion").help("Reduce optional animation")
      Button("Restart", systemImage: "arrow.counterclockwise") { restart = true }.labelStyle(
        .iconOnly
      ).help("Start a fresh household")
    }.buttonStyle(.borderless).padding(.horizontal, 28).padding(.vertical, 16)
  }
  private var heading: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 5) {
        Text("\(Content.seasons[state.season].uppercased()) · YEAR ONE").font(
          .caption.weight(.semibold)
        ).tracking(2)
        Text(
          state.phase == .ending
            ? "What a year can hold."
            : [
              "A new beginning.", "Under the summer sun.", "The season of keeping.",
              "A light in the window.",
            ][state.season]
        ).font(.custom("CormorantGaramondLight-Medium", size: 42, relativeTo: .largeTitle))
        Text(Rules.seasonSubtitle(state)).foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 18) {
        ForEach(0..<4) { i in
          VStack(spacing: 5) {
            Image(
              systemName: i < state.season
                ? "checkmark.circle.fill" : ["leaf", "sun.max", "leaf.fill", "snowflake"][i])
            Text(Content.seasons[i]).font(.caption)
          }.foregroundStyle(i == state.season ? ink : ink.opacity(0.45)).accessibilityLabel(
            "\(Content.seasons[i])\(i == state.season ? ", current season" : "")")
        }
      }
    }
  }
  private var resources: some View {
    HStack(spacing: 16) {
      resource("Food", value: "\(state.food)", detail: "4 needed for spring seed", symbol: "leaf")
      resource("Money", value: "\(state.money)", detail: "Coins to your name", symbol: "circle")
      resource(
        "Shelter", value: "\(state.house)/100",
        detail: state.house >= 65 ? "A roof that holds" : "The house needs care", symbol: "house")
      resource(
        "Free hands", value: "\(state.assignments.values.filter { $0 == .rest }.count)/3",
        detail: "Three adults, one household", symbol: "person.2")
    }
  }
  private func resource(_ title: String, value: String, detail: String, symbol: String) -> some View
  {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol).font(.title3).padding(10).background(
        ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.caption).foregroundStyle(.secondary)
        Text(value).font(.system(size: 25, weight: .medium, design: .serif))
        Text(detail).font(.caption).foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(
      .white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
  }
  @ViewBuilder private var commitment: some View {
    if state.ox == "borrowed" || state.reservedWorker != nil {
      Label(
        state.reservedWorker != nil
          ? "A promise kept · Petru is helping Vasile this autumn."
          : "A promise to remember · One adult owes Vasile help in autumn.", systemImage: "heart"
      ).font(.callout).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(
        ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
  }
  private var household: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("The household").font(.system(size: 24, design: .serif))
      if state.phase == .work {
        WorkView(session: session)
      } else {
        HStack(alignment: .top) {
          ForEach(WorkerID.allCases, id: \.self) { worker in
            let person = Content.shared.people[worker.rawValue]!
            VStack(alignment: .leading, spacing: 4) {
              Text(person.name).font(.headline)
              Text(person.role).font(.caption).foregroundStyle(.secondary)
              Text(person.line).font(.caption).italic().fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
    }.padding(18).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
  }
  private var phasePanel: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(
        [
          Phase.opening: "A conversation", .work: "Plan your work",
          .consequence: "As evening falls", .summary: "Season remembered",
          .ending: "Your first year",
        ][state.phase]!
      ).font(.caption.weight(.semibold)).tracking(1).accessibilityAddTraits(.isHeader)
        .accessibilityFocused($panelFocused)
      switch state.phase {
      case .opening, .consequence: ConversationView(session: session, state: state)
      case .work:
        Text("A season’s work").font(.system(size: 30, design: .serif))
        Text(
          "Give each adult one task. Work costs must be affordable before wages or harvest come home."
        ).foregroundStyle(.secondary)
        let p = Rules.preview(state)
        Divider()
        Text("After work and consumption").font(.headline)
        Text("Food: \(p.foodAfter)\nMoney: \(p.moneyAfter)\nShelter: \(p.houseAfter)/100")
          .lineSpacing(8)
        Text("The evening conversation may change these numbers.").font(.caption).foregroundStyle(
          .secondary)
        ForEach(p.errors, id: \.self) { Text($0).foregroundStyle(.red) }
        ForEach(p.warnings, id: \.self) {
          Text($0).font(.callout).foregroundStyle(Color(red: 0.48, green: 0.28, blue: 0.12))
        }
        Button("Review and complete work") { confirmWork = true }.buttonStyle(.borderedProminent)
          .disabled(!p.errors.isEmpty)
      case .summary:
        Text("\(Content.seasons[state.season]), remembered").font(.system(size: 30, design: .serif))
        if let r = state.report {
          ForEach(r.tasks, id: \.self) { Text($0).font(.callout) }
          Divider()
          Text(
            "Food \(r.foodBefore) → \(r.foodAfter)\nMoney \(r.moneyBefore) → \(r.moneyAfter)\nShelter \(r.houseBefore) → \(r.houseAfter)"
          ).lineSpacing(8)
          Text("Consumed \(r.consumption) food · Weathering \(r.wear)").font(.caption)
            .foregroundStyle(.secondary)
          if r.deficit > 0 {
            Text("Food shortfall: \(r.deficit). Recorded as hardship.").foregroundStyle(.red)
          }
        }
        Button(
          state.season == 3
            ? "See what the year has meant"
            : "Continue to \(Content.seasons[min(3,state.season+1)])"
        ) { session.send(Action(type: "continue", revision: state.revision)) }.buttonStyle(
          .borderedProminent)
      case .ending:
        let end = Rules.ending(state)
        Text(end.title).font(.system(size: 30, design: .serif))
        Text(end.text).lineSpacing(5)
        ForEach(end.decisions, id: \.event) { h in
          VStack(alignment: .leading, spacing: 4) {
            Text(h.title).font(.headline)
            Text(h.detail).font(.callout).foregroundStyle(.secondary)
          }
        }
        Button("Open the promise journal") { sheet = "journal" }.buttonStyle(.bordered)
        Button("Begin another household") { restart = true }.buttonStyle(.borderedProminent)
      }
    }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(
      .white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
  }
  private var recovery: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Your household needs attention").font(.largeTitle)
      Text(session.error ?? "The saved household could not be opened.")
      Text(
        "Your existing save has been left untouched. Retry opening it, or keep a recovery copy and begin a fresh household."
      )
      HStack {
        Button("Retry opening save") { session.retryLoad() }
        Button("Start a fresh household") { restart = true }
      }
    }.frame(maxWidth: 650, alignment: .leading)
  }
  private func banner(_ text: String, symbol: String) -> some View {
    Label(text, systemImage: symbol).font(.callout).padding(12).frame(
      maxWidth: .infinity, alignment: .leading
    ).background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
      .accessibilityAddTraits(.updatesFrequently)
  }
  private func refreshScene() {
    scene.update(state: state, reducedMotion: reduced)
    resourceWarning = scene.resourceWarning
  }
  private func hotspot(_ spot: Hotspot) {
    guard !session.needsRecovery else { return }
    if spot == .visitor {
      panelFocused = true
      return
    }
    guard state.phase == .work else {
      panelFocused = true
      session.error = "Finish the current conversation before assigning work."
      return
    }
    let task: TaskID? =
      spot == .house
      ? .repair
      : spot == .stores
        ? .supplies
        : state.season == 0
          ? .plant : state.season == 1 ? .tend : state.season == 2 ? .harvest : nil
    guard let task else {
      session.error = "The field is resting beneath the snow."
      return
    }
    guard Rules.taskOptions(state).contains(where: { $0.id == task }) else {
      session.error = "The field was not planted in spring. Choose another household task."
      return
    }
    selectedTask = task
    sheet = "task"
  }
}
private struct SheetID: Identifiable {
  let id: String
  init(_ id: String) { self.id = id }
}
