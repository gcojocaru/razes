import Combine
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
  @State private var cameraZoom = 111
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
            mapControls
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
              if ui.debug || ui.selection != nil || ui.buildMode {
                GamePanel {
                  VStack(alignment: .leading, spacing: 12) {
                    HStack {
                      Text(ui.debug ? "DEBUG BUILDER" : ui.buildMode ? "CONSTRUCTION" : "SELECTED")
                        .font(
                          .system(size: 10, weight: .semibold)
                        ).tracking(2).foregroundStyle(GamePalette.gold)
                      Spacer()
                      Button("Close", systemImage: "xmark") { ui.dismissOptional() }.labelStyle(
                        .iconOnly
                      )
                    }
                    GameScroll(maximumHeight: min(420, geometry.size.height - 260)) {
                      if ui.debug {
                        DebugBuildPanel(session: session, state: state, place: beginPlacement)
                      } else if let selection = ui.selection {
                        SelectionInspector(
                          session: session, state: state, selection: selection,
                          beginPlacement: beginPlacement)
                      } else {
                        BuildPanel(
                          state: state,
                          select: { id in
                            if Construction.stage(id, state: state) != .empty {
                              choose(.building(id))
                            } else {
                              beginPlacement(.building(id, worker: nil, instant: false))
                            }
                          })
                      }
                    }
                  }
                }.frame(width: 300)
              }
            }.padding(.horizontal, 18).padding(.bottom, 12)
            GameHUD(
              state: state, selection: ui.selection, buildMode: ui.buildMode, choose: choose,
              build: {
                let show = !ui.buildMode
                ui.dismissOptional()
                ui.buildMode = show
              },
              primary: {
                ui.dismissOptional()
                ui.review = true
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
              "Read the seasonal conversation, then select a household portrait or a place in the homestead to assign work. Each adult has one assignment. End season opens a forecast; confirm to resolve work, then answer the evening conversation.\n\nBuild lets you choose free locations on the isometric map. Drag or scroll to pan, and pinch or Option-scroll to zoom. The map controls also provide pan, zoom and a Home reset. Green placement footprints are free; red footprints are occupied, outside the map or reserved for the house and farmland. Click to place; Escape cancels. Construction starts immediately and runs in real time, independently of seasonal workers. Ten building types produce food and coins every minute at their current level. Select a building to upgrade it (up to level 5), repair it or move its plot. Upgrades cost the base price times the target level and take one minute per target level. Repairs take 20 seconds. Work pauses production and wear. Buildings lose four condition per hour; at zero they lose a level and return to 60 condition. Level 1 becomes inactive at zero until repaired. Reopening catches up at most 24 hours; timers also run after the first-year ending. The starter house keeps its seasonal shelter and repair rules. Debug offers free completion, levels, condition, resources and time jumps.\n\nHarvest needs two adults. Honouring the ox promise reserves Petru in autumn. All choices and draft assignments save on this Mac.\n\nCommand-J opens the journal. The Places menu provides keyboard alternatives to scene targets. Escape closes optional commands; conversations remain until answered."
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
    .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
      session.tick(now: date.timeIntervalSince1970)
    }
    .onExitCommand { ui.dismissOptional() }
    .onAppear {
      if keyMonitor == nil {
        // SpriteKit consumes Escape before SwiftUI's exit command sees it.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
          guard event.keyCode == 53, event.window === scene.view?.window,
            event.window?.attachedSheet == nil, sheet == nil, !restart
          else { return event }
          ui.dismissOptional()
          return nil
        }
      }
      scene.onCameraChange = { cameraZoom = $0 }
      scene.onSelection = choose
      scene.onPlacement = place
      session.tick()
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
    .onChange(of: ui.placement) { scene.setPlacement(ui.placement) }
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
      Button("Debug", systemImage: "wrench.and.screwdriver") {
        ui.dismissOptional()
        ui.debug = true
      }
      .help("Building and construction debug workshop")
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
    if mandatory, case .worker = selection {
      ui.review = true
      return
    }
    ui.dismissOptional()
    ui.selection = selection
    ui.review = false
  }
  private func beginPlacement(_ tool: PlacementTool) {
    ui.dismissOptional()
    ui.placement = tool
  }
  private func place(_ tool: PlacementTool, at point: GridPosition) {
    switch tool {
    case .building(let id, let worker, let instant):
      guard session.placeBuilding(id, at: point, instant: instant) else { return }
      if let worker, let task = Construction.definition(id).task {
        session.send(
          .init(
            type: "assign", revision: session.state.revision, worker: worker,
            task: task))
      }
      ui.placement = nil
      ui.selection = .building(id)
      ui.review = false
    case .scenery(let kind):
      guard session.placeScenery(kind, at: point) else { return }
    }
  }
  private var mapControls: some View {
    HStack(spacing: 8) {
      if let tool = ui.placement {
        Label("Place \(tool.title) · click a green footprint", systemImage: "square.dashed").font(
          .caption)
        Button("Cancel placement") { ui.dismissOptional() }
      }
      Spacer()
      HStack(spacing: 6) {
        Menu("Pan") {
          Button("North") { scene.panCamera(x: 0, y: 100) }
          Button("South") { scene.panCamera(x: 0, y: -100) }
          Button("West") { scene.panCamera(x: -100, y: 0) }
          Button("East") { scene.panCamera(x: 100, y: 0) }
        }.fixedSize()
        Button("Zoom out", systemImage: "minus.magnifyingglass") { scene.zoomCamera(1.2) }
          .labelStyle(.iconOnly)
        Text("\(cameraZoom)%").font(.caption.monospacedDigit()).frame(width: 42)
        Button("Home", systemImage: "house") { scene.resetCamera() }.labelStyle(.iconOnly)
        Button("Zoom in", systemImage: "plus.magnifyingglass") { scene.zoomCamera(1 / 1.2) }
          .labelStyle(.iconOnly)
      }.padding(8).background(
        GamePalette.panel.opacity(0.94), in: RoundedRectangle(cornerRadius: 5))
    }.padding(.horizontal, 18).padding(.top, 8)
      .help("Drag or scroll to pan. Pinch or Option-scroll to zoom. Escape cancels placement.")
  }
  private func refreshScene() {
    scene.update(
      state: state, reducedMotion: reduced,
      animateChanges: session.acceptedRevision == state.revision)
    scene.select(ui.selection, buildMode: ui.buildMode)
    scene.setPlacement(ui.placement)
    resourceWarning = scene.resourceWarning
  }
}
private struct SheetID: Identifiable {
  let id: String
  init(_ id: String) { self.id = id }
}
