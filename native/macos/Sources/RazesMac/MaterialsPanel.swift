import RazesCore
import SwiftUI

struct MaterialsPanel: View {
  @Bindable var session: GameSession
  let state: GameState
  @State private var quantity = 1
  private var freeCoins: Int {
    state.money - (state.phase == .work ? Rules.preview(state).moneyCost : 0)
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Food: \(state.food) · Coins: \(state.money)").font(.headline)
      Text("FOOD PROVISIONS").font(.headline)
      Text("\(Rules.suppliesGain(state)) food · 4 coins · arrives at week end")
      Text(
        "Ion buys provisions instead of another weekly job. Food does not use material storage slots."
      )
      .font(.caption).foregroundStyle(GamePalette.muted)
      if state.phase == .work {
        let target: TaskID = state.assignments["ion"] == .supplies ? .rest : .supplies
        let reason = Rules.assignmentProblem(state, worker: .ion, task: target)
        Button(target == .rest ? "Cancel food purchase" : "Assign Ion to buy food") {
          session.send(
            .init(type: "assign", revision: session.state.revision, worker: .ion, task: target))
        }.disabled(reason != nil)
        if let reason { Text(reason).font(.caption).foregroundStyle(GamePalette.muted) }
      } else {
        Text("Continue to weekly planning to buy food.").font(.caption)
      }
      Divider()
      Text("Shared storage: \(state.materials.total) / \(Materials.capacity(state))")
        .font(.title3).accessibilityAddTraits(.isHeader)
      Text(
        "Wood, stone and planks each take one slot. Food, seeds and coins are stored separately."
      )
      .font(.caption).foregroundStyle(GamePalette.muted)
      if state.materials.total > Materials.capacity(state) {
        Text(
          "Over capacity after storage damage. Your supplies are safe; spend or discard some to make room."
        )
        .foregroundStyle(.orange)
      }
      if Materials.reserved(state).total > 0 {
        Text("Reserved for weekly building work: \(Materials.reserved(state).text)")
          .font(.caption).foregroundStyle(GamePalette.gold)
      }
      Stepper("Quantity: \(quantity)", value: $quantity, in: 1...100)
      HStack {
        Text("Grain seeds: \(state.seeds)").frame(maxWidth: .infinity, alignment: .leading)
        Button("Buy \(quantity) grain seeds · \(quantity) coins") {
          session.buySeeds(quantity: quantity)
        }.disabled(freeCoins < quantity || state.seeds > 100000 - quantity)
      }
      Text(
        "Planting window: Spring only — all 12 weeks, once per year. Plant 4 seeds through Places → Field. Grain ripens after 24 weeks."
      )
      .font(.caption).foregroundStyle(GamePalette.muted)
      ForEach(MaterialID.allCases, id: \.self) { id in
        HStack {
          Text("\(id.title): \(state.materials[id])").frame(
            maxWidth: .infinity, alignment: .leading)
          Button("Buy \(quantity) \(id.rawValue) · \(quantity * id.price) coins") {
            session.buyMaterials(id, quantity: quantity)
          }.disabled(
            freeCoins < quantity * id.price
              || state.materials.total + quantity > Materials.capacity(state))
          Button("Discard \(quantity) \(id.rawValue)", role: .destructive) {
            session.discardMaterials(id, quantity: quantity)
          }.disabled(Materials.available(state)[id] < quantity)
        }
      }
      Text("Buying is immediate. \(freeCoins) coins are free to spend. Discarding has no refund.")
        .font(.caption).foregroundStyle(GamePalette.muted)
      Divider()
      Text("CRAFTING").font(.headline)
      Button("Craft \(quantity) planks · uses \(quantity * 2) wood") {
        session.craftPlanks(quantity: quantity)
      }.disabled(
        Materials.available(state).wood < quantity * 2
          || state.materials.total - quantity > Materials.capacity(state))
      Text(
        "Immediate · no worker needed · 2 wood → 1 plank. Ingredients free their storage space first."
      )
      .font(.caption).foregroundStyle(GamePalette.muted)
      Divider()
      Text("WEEKLY GATHERING").font(.headline)
      if state.phase == .work {
        ForEach(WorkerID.allCases, id: \.self) { worker in
          HStack {
            Text(Content.shared.people[worker.rawValue]!.name).frame(width: 55, alignment: .leading)
            Picker(
              "\(Content.shared.people[worker.rawValue]!.name)'s gathering assignment",
              selection: Binding(
                get: { Materials.assignments(state)[worker.rawValue] ?? .rest },
                set: {
                  session.send(
                    .init(
                      type: "assign", revision: session.state.revision, worker: worker, task: $0))
                }
              )
            ) {
              let current = Materials.assignments(state)[worker.rawValue] ?? .rest
              if ![TaskID.rest, .gatherWood, .gatherStone].contains(current) {
                Text(Rules.task(current).name).tag(current)
              }
              Text("Rest").tag(TaskID.rest)
              Text(
                "Gather timber · up to \(Materials.gatheringYield(.gatherWood, state: state)) wood"
              ).tag(TaskID.gatherWood)
                .disabled(Rules.assignmentProblem(state, worker: worker, task: .gatherWood) != nil)
              Text(
                "Gather stone · up to \(Materials.gatheringYield(.gatherStone, state: state)) stone"
              ).tag(TaskID.gatherStone)
                .disabled(Rules.assignmentProblem(state, worker: worker, task: .gatherStone) != nil)
            }.labelsHidden()
          }
        }
        let haul = Materials.forecast(state)
        ForEach(haul.lines, id: \.self) { Text($0).font(.caption) }
        Text(
          "Arrives when weekly work resolves. Free storage limits Ion’s haul."
        )
        .font(.caption).foregroundStyle(GamePalette.muted)
      } else {
        Text(
          "Assign gathering during weekly planning. Ion can gather instead of another job."
        )
        .font(.caption)
      }
      if let haul = state.lastMaterialHaul {
        Text("Last haul: \(haul.text)").font(.caption).foregroundStyle(GamePalette.gold)
      }
      Divider()
      HouseStorageControls(session: session, state: state)
      Text(
        "Build a storehouse for +40 shared storage per completed level. Its foundation finishes at season end."
      )
      .font(.caption).foregroundStyle(GamePalette.muted)
      if let error = session.error { Text(error).foregroundStyle(.orange) }
      if let warning = session.storageWarning { Text(warning).foregroundStyle(.orange) }
    }.buttonStyle(.bordered).disabled(state.phase == .dead)
  }
}

struct HouseStorageControls: View {
  @Bindable var session: GameSession
  let state: GameState
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(
        "House storage · level \(state.houseLevel)/5 · \(20 + (state.houseLevel - 1) * 10) slots"
      )
      .font(.headline)
      if state.houseLevel < 5 {
        Text("+10 slots · \(Materials.houseUpgradeMaterials.text)").font(.caption)
        Button("Upgrade house storage · \(4 * (state.houseLevel + 1)) coins") {
          session.upgradeHouseStorage()
        }
      }
    }
  }
}

struct HouseStockOverview: View {
  let state: GameState
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("HOUSE STOCKS").font(.caption).foregroundStyle(GamePalette.gold)
      LabeledContent("Food", value: "\(state.food)")
        .accessibilityElement(children: .ignore).accessibilityLabel("Food").accessibilityValue(
          "\(state.food)")
      LabeledContent("Coins", value: "\(state.money)")
        .accessibilityElement(children: .ignore).accessibilityLabel("Coins").accessibilityValue(
          "\(state.money)")
      LabeledContent("Grain seeds", value: "\(state.seeds)")
        .accessibilityElement(children: .ignore).accessibilityLabel("Grain seeds")
        .accessibilityValue("\(state.seeds)")
      ForEach(MaterialID.allCases, id: \.self) { material in
        LabeledContent(material.title, value: "\(state.materials[material])")
          .accessibilityElement(children: .ignore).accessibilityLabel(material.title)
          .accessibilityValue("\(state.materials[material])")
      }
      Text("Material storage: \(state.materials.total) / \(Materials.capacity(state))")
        .font(.caption)
      ProgressView(
        value: Double(min(state.materials.total, Materials.capacity(state))),
        total: Double(Materials.capacity(state))
      )
      .accessibilityLabel("Material storage")
      .accessibilityValue("\(state.materials.total) of \(Materials.capacity(state)) slots")
      if Materials.reserved(state).total > 0 {
        Text("Reserved for work: \(Materials.reserved(state).text)").font(.caption)
          .foregroundStyle(GamePalette.gold)
      }
      if state.materials.total > Materials.capacity(state) {
        Text("Storage is over capacity. Existing stocks are safe; free space before buying more.")
          .font(.caption).foregroundStyle(.orange)
      }
      Text("Food use this week: \(Rules.consumption(state, house: state.house))")
        .font(.caption).foregroundStyle(GamePalette.muted)
    }
  }
}
