import RazesCore
import SwiftUI

struct CharacterNeedsView: View {
  let character: CharacterState
  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      LabeledContent("Health", value: "\(character.health)/100")
        .accessibilityElement(children: .ignore).accessibilityLabel("Health")
        .accessibilityValue("\(character.health) of 100")
      LabeledContent("Energy", value: "\(character.energy)/100")
        .accessibilityElement(children: .ignore).accessibilityLabel("Energy")
        .accessibilityValue("\(character.energy) of 100")
      LabeledContent("Hunger", value: "\(character.hunger)/100")
        .accessibilityElement(children: .ignore).accessibilityLabel("Hunger")
        .accessibilityValue("\(character.hunger) of 100")
    }.monospacedDigit().font(.caption)
  }
}

struct CharacterSkillsView: View {
  let character: CharacterState
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      CharacterNeedsView(character: character)
      Text("Higher hunger means greater danger. At 75 hunger, Ion loses 15 health each week.")
        .font(.caption).foregroundStyle(GamePalette.muted)
      if character.health < 25 {
        Label(
          "Poor health: every job costs 10 extra energy.", systemImage: "exclamationmark.triangle"
        )
        .font(.caption).foregroundStyle(.orange)
      }
      ForEach(SkillID.allCases, id: \.self) { skill in
        VStack(alignment: .leading, spacing: 3) {
          LabeledContent(skill.title, value: "Level \(character.level(skill))/5")
          ProgressView(value: Double(character[skill]), total: 12)
            .accessibilityLabel("\(skill.title) experience")
            .accessibilityValue("\(character[skill]) of 12; level \(character.level(skill)) of 5")
          Text("\(character[skill])/12 XP · productive work earns 1 XP")
            .font(.caption).foregroundStyle(GamePalette.muted)
          Group {
            switch skill {
            case .farming: Text("Each level above 1 adds 2 harvest food.")
            case .gathering: Text("Each level above 1 adds 1 gathered unit before storage limits.")
            case .building: Text("Each level above 1 adds 5 shelter restored by house repairs.")
            }
          }.font(.caption).foregroundStyle(GamePalette.muted)
        }
      }
    }
  }
}

struct CharacterWeekView: View {
  let week: CharacterWeek
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("Health \(week.before.health) → \(week.after.health)")
      Text("Energy \(week.before.energy) → \(week.after.energy)")
      Text("Hunger \(week.before.hunger) → \(week.after.hunger)")
      if week.starvationDamage > 0 {
        Label(
          "Starvation: −\(week.starvationDamage) health", systemImage: "exclamationmark.triangle"
        )
        .foregroundStyle(.orange)
      }
      if week.exposureDamage > 0 {
        Label("Winter exposure: −\(week.exposureDamage) health", systemImage: "snowflake")
          .foregroundStyle(.orange)
      }
      ForEach(SkillID.allCases, id: \.self) { skill in
        if week.after[skill] > week.before[skill] {
          Text(
            "\(skill.title): +\(week.after[skill] - week.before[skill]) XP · level \(week.after.level(skill))/5"
          )
          .foregroundStyle(GamePalette.gold)
        }
      }
    }.font(.caption).monospacedDigit()
  }
}
