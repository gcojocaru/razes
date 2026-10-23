import Foundation
import Observation
import RazesCore

@MainActor @Observable final class GameSession {
  private(set) var state = Rules.newGame()
  private(set) var needsRecovery = false
  private(set) var hasSaved = false
  private(set) var acceptedRevision: Int?
  var error: String?
  var storageWarning: String?
  private let store: SaveStore?
  let audio = Ambience()
  var soundEnabled = false { didSet { audio.setEnabled(soundEnabled && active) } }
  var active = true { didSet { audio.setEnabled(soundEnabled && active) } }
  var reduceMotion = false
  init(store: SaveStore?, startupError: String? = nil) {
    self.store = store
    if let startupError { storageWarning = startupError } else { retryLoad() }
  }
  static func applicationSession(arguments: [String] = CommandLine.arguments) -> GameSession {
    #if DEBUG
      if let index = arguments.firstIndex(of: "--validation-save"), index + 1 < arguments.count {
        return GameSession(store: SaveStore(url: URL(fileURLWithPath: arguments[index + 1])))
      }
    #endif
    do { return GameSession(store: try SaveStore.applicationStore()) } catch {
      return GameSession(
        store: nil, startupError: "Saving is unavailable: \(error.localizedDescription)")
    }
  }
  func retryLoad() {
    acceptedRevision = nil
    guard let store else { return }
    do {
      if let loaded = try store.load() {
        state = loaded
        hasSaved = true
      } else {
        state = Rules.newGame()
        hasSaved = false
      }
      needsRecovery = false
      error = nil
      storageWarning = nil
    } catch {
      needsRecovery = true
      self.error = error.localizedDescription
    }
  }
  func send(_ action: Action) {
    guard !needsRecovery else { return }
    do {
      state = try Rules.dispatch(state, action: action)
      acceptedRevision = state.revision
      error = nil
      do {
        guard let store else { throw GameError("The save location is unavailable.") }
        try store.save(state)
        storageWarning = nil
        hasSaved = true
      } catch {
        storageWarning =
          "Your run continues, but changes could not be saved: \(error.localizedDescription)"
      }
      audio.cue()
    } catch { self.error = error.localizedDescription }
  }
  func startFresh() {
    let fresh = Rules.newGame()
    do {
      guard let store else { throw GameError("The save location is unavailable.") }
      try store.startFresh(fresh)
      acceptedRevision = nil
      state = fresh
      needsRecovery = false
      error = nil
      storageWarning = nil
      hasSaved = true
    } catch { self.error = "Could not safely start fresh: \(error.localizedDescription)" }
  }
}
