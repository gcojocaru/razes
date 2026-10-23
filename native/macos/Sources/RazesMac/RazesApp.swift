import CoreText
import SwiftUI

@main struct RazesApp: App {
  @State private var session = GameSession.applicationSession()
  init() {
    for name in ["dm-sans-latin-400-normal", "cormorant-garamond-latin-500-normal"] {
      if let url = Bundle.module.url(
        forResource: name, withExtension: "woff2", subdirectory: "Resources/Fonts")
      {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
      }
    }
  }
  var body: some Scene {
    Window("Răzeș", id: "main") { ContentView(session: session) }
      .defaultSize(width: 1280, height: 850)
      .commands { CommandGroup(replacing: .newItem) {} }
  }
}
