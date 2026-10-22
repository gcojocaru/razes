import RazesCore
import SwiftUI

struct JournalView: View {
  let state: GameState
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      if state.history.isEmpty {
        Text("A new year waits to be remembered. Your choices and promises will be recorded here.")
      }
      ForEach(0..<4) { season in
        let history = state.history.filter { $0.season == season }
        let memories = state.memories.filter { $0.season == season }
        if !history.isEmpty || !memories.isEmpty {
          Text(Content.seasons[season]).font(.title2).accessibilityAddTraits(.isHeader)
          ForEach(history, id: \.event) { h in
            VStack(alignment: .leading, spacing: 5) {
              Text(h.title).font(.headline)
              Text(h.detail).foregroundStyle(.secondary)
            }
          }
          ForEach(memories.filter { $0.id.hasPrefix("help-") }, id: \.id) { m in
            VStack(alignment: .leading, spacing: 5) {
              Text(m.title).font(.headline)
              Text(m.detail).foregroundStyle(.secondary)
            }
          }
          Divider()
        }
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}
