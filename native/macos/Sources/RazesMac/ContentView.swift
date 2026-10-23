import RazesCore
import SpriteKit
import SwiftUI

struct ContentView: View {
  @Bindable var session: GameSession
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var scene = HomesteadScene()
  @State private var ui = GameUIState()
  @State private var resourceWarning: String?
  @State private var sheet: String?
  @State private var restart = false
  @State private var keyMonitor: Any?
  private var state: GameState { session.state }
  private var reduced: Bool { systemReduceMotion || session.reduceMotion }
  private var mandatory: Bool { state.phase == .opening || state.phase == .consequence }
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        GamePalette.ink.ignoresSafeArea()
        if session.needsRecovery {
          recovery.padding(40)
        } else {
          SpriteView(scene: scene, preferredFramesPerSecond: 30).accessibilityHidden(true)
          VStack(spacing: 0) {
            topStrip
            warnings
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 16) {
              if mandatory || ui.review {
                GamePanel {
                  GameScroll(maximumHeight: min(380, geometry.size.height * 0.46)) {
                    PhaseOverlay(
                      session: session, state: state, close: { ui.review = false },
                      restart: { restart = true }, journal: { sheet = "journal" })
                  }
                }.frame(maxWidth: 760)
              }
              Spacer(minLength: 0)
              if !mandatory, ui.selection != nil || ui.buildMode {
                GamePanel {
                  VStack(alignment: .leading, spacing: 12) {
                    HStack {
                      Text(ui.buildMode ? "CONSTRUCTION" : "SELECTED").font(
                        .system(size: 10, weight: .semibold)
                      ).tracking(2).foregroundStyle(GamePalette.gold)
                      Spacer()
                      Button("Close", systemImage: "xmark") { ui.dismissOptional() }.labelStyle(
                        .iconOnly
                      )
                    }
                    GameScroll(maximumHeight: min(420, geometry.size.height - 260)) {
                      if let selection = ui.selection {
                        SelectionInspector(session: session, state: state, selection: selection)
                      } else {
                        BuildPanel(state: state, select: { choose(.building($0)) })
                      }
                    }
                  }
                }.frame(width: 300)
              }
            }.padding(.horizontal, 18).padding(.bottom, 12)
            GameHUD(
              state: state, selection: ui.selection, buildMode: ui.buildMode, choose: choose,
              build: {
                ui.review = false
                ui.buildMode.toggle()
                ui.selection = nil
              },
              primary: {
                ui.review = true
                ui.selection = nil
                ui.buildMode = false
              })
          }
        }
      }
    }
    .font(.custom("DMSans9pt-Regular", size: 13, relativeTo: .body))
    .foregroundStyle(GamePalette.paper).tint(GamePalette.gold).preferredColorScheme(.dark)
    .frame(minWidth: 1000, minHeight: 700)
    .sheet(item: Binding(get: { sheet.map(SheetID.init) }, set: { sheet = $0?.id })) { item in
      VStack(alignment: .leading, spacing: 18) {
        HStack {
          Text(item.id == "journal" ? "The promise journal" : "How to play").font(
            .system(size: 28, design: .serif))
          Spacer()
          Button("Done") { sheet = nil }.keyboardShortcut(.cancelAction)
        }
        ScrollView {
          if item.id == "journal" {
            JournalView(state: state)
          } else {
            Text(
              "Read the seasonal conversation, then select a household portrait or a place in the homestead to assign work. Each adult has one assignment. End season opens a forecast; confirm to resolve work, then answer the evening conversation.\n\nBuild reveals two fixed plots. A woodshed costs 3 money and reduces winter consumption and wear; a root cellar costs 4 money and improves provisions purchases. Both require one adult’s assignment, finish when work resolves and help from the following season. Construction is unavailable in winter. Select the plot to change or cancel its builder.\n\nHarvest needs two adults. Honouring the ox promise reserves Petru in autumn. All choices and draft assignments save on this Mac.\n\nCommand-J opens the journal. The Places menu provides keyboard alternatives to scene targets. Escape closes optional commands; conversations remain until answered."
            ).lineSpacing(5)
          }
        }
      }.padding(26).frame(width: 620, height: 480).background(GamePalette.panel)
    }
    .alert("Begin a fresh household?", isPresented: $restart) {
      Button("Cancel", role: .cancel) {}
      Button("Start fresh", role: .destructive) {
        session.startFresh()
        ui.changedPhase()
      }
    } message: {
      Text("Your existing save will be preserved as a recovery copy before a new year begins.")
    }
    .onExitCommand { ui.dismissOptional() }
    .onAppear {
      if keyMonitor == nil {
        // SpriteKit consumes Escape before SwiftUI's exit command sees it.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
          guard event.keyCode == 53, event.window === scene.view?.window,
            event.window?.attachedSheet == nil, sheet == nil, !restart, !mandatory
          else { return event }
          ui.dismissOptional()
          return nil
        }
      }
      scene.onSelection = choose
      if state.phase == .work { ui.review = false }
      refreshScene()
    }
    .onDisappear {
      if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
      keyMonitor = nil
    }
    .onChange(of: state) { old, new in
      if old.phase != new.phase {
        ui.changedPhase()
        if new.phase == .work { ui.review = false }
      }
      refreshScene()
    }
    .onChange(of: ui.selection) { scene.select(ui.selection, buildMode: ui.buildMode) }
    .onChange(of: ui.buildMode) { scene.select(ui.selection, buildMode: ui.buildMode) }
    .onChange(of: reduced) { refreshScene() }
    .onChange(of: scenePhase) { session.active = scenePhase == .active }
    .background {
      Button("Open journal") { sheet = "journal" }.keyboardShortcut("j", modifiers: .command)
        .hidden()
    }
  }
  private var topStrip: some View {
    HStack(spacing: 18) {
      Text("Răzeș").font(.system(size: 20, design: .serif)).foregroundStyle(GamePalette.gold)
      Text("\(Content.seasons[state.season].uppercased()) · 1495").font(
        .system(size: 10, weight: .semibold)
      ).tracking(1)
      Divider().frame(height: 18).overlay(GamePalette.gold.opacity(0.4))
      resource("Food", value: "\(state.food)", icon: "leaf")
      resource("Money", value: "\(state.money)", icon: "circle")
      resource("Shelter", value: "\(state.house)", icon: "house")
      resource(
        "Free", value: "\(state.assignments.values.filter{$0 == .rest}.count)/3", icon: "person.2")
      Spacer(minLength: 0)
      Menu("Places") {
        ForEach(Hotspot.allCases, id: \.rawValue) { spot in
          Button(spot.rawValue.capitalized) { choose(.hotspot(spot)) }
        }
        Divider()
        ForEach(BuildingID.allCases, id: \.self) { id in
          Button(Construction.definition(id).title) { choose(.building(id)) }
        }
      }.menuStyle(.borderlessButton).fixedSize()
      Menu {
        Button("Promise journal") { sheet = "journal" }
        Button("How to play") { sheet = "help" }
        Divider()
        Toggle("Ambient sound", isOn: $session.soundEnabled)
        Toggle("Reduce motion", isOn: $session.reduceMotion)
        Divider()
        Text(session.hasSaved ? "Saved on this Mac" : "A new household")
        Button("Start a fresh household") { restart = true }
      } label: {
        Image(systemName: "gearshape").accessibilityLabel("Game menu")
      }.menuStyle(.borderlessButton).frame(width: 24)
    }.padding(.horizontal, 18).frame(height: 48).background(GamePalette.panel.opacity(0.96))
      .overlay(alignment: .bottom) {
        Rectangle().fill(GamePalette.gold.opacity(0.7)).frame(height: 1)
      }
  }
  private func resource(_ label: String, value: String, icon: String) -> some View {
    HStack(spacing: 5) {
      Image(systemName: icon).foregroundStyle(GamePalette.gold)
      Text(label).foregroundStyle(GamePalette.muted)
      Text(value).monospacedDigit().fontWeight(.semibold)
    }.font(.system(size: 12)).accessibilityElement(children: .combine)
  }
  private var warnings: some View {
    VStack(spacing: 3) {
      if let warning = session.storageWarning { notice(warning) }
      if let warning = resourceWarning { notice(warning) }
      if let error = session.error {
        HStack {
          notice(error)
          Button("Dismiss") { session.error = nil }.font(.caption)
        }.background(GamePalette.panel)
      }
    }
  }
  private func notice(_ text: String) -> some View {
    Label(text, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(
      GamePalette.gold
    ).padding(8).frame(maxWidth: .infinity, alignment: .leading).background(
      GamePalette.panel.opacity(0.97))
  }
  private var recovery: some View {
    GamePanel {
      VStack(alignment: .leading, spacing: 18) {
        Text("Your household needs attention").font(.largeTitle)
        Text(session.error ?? "This save could not be opened.")
        Text(
          "Your saved household has been left untouched. Retry, or preserve a recovery copy and start fresh."
        )
        HStack {
          Button("Retry opening save") { session.retryLoad() }
          Button("Start a fresh household") { restart = true }
        }
      }.frame(maxWidth: 620, alignment: .leading)
    }
  }
  private func choose(_ selection: SceneSelection) {
    guard !session.needsRecovery else { return }
    if mandatory {
      ui.review = true
      return
    }
    ui.selection = selection
    ui.review = false
  }
  private func refreshScene() {
    scene.update(
      state: state, reducedMotion: reduced,
      animateChanges: session.acceptedRevision == state.revision)
    scene.select(ui.selection, buildMode: ui.buildMode)
    resourceWarning = scene.resourceWarning
  }
}
private struct SheetID: Identifiable {
  let id: String
  init(_ id: String) { self.id = id }
}
