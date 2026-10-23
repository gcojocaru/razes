import AppKit
import SwiftUI

struct PortraitView: View {
  let person: String
  @MainActor private static var portraits: [String: NSImage] = [:]
  @MainActor private var portrait: NSImage? {
    if let cached = Self.portraits[person] { return cached }
    guard let column = ["ion"].firstIndex(of: person),
      let url = Bundle.module.url(
        forResource: "people", withExtension: "png", subdirectory: "Resources/Art"),
      let image = NSImage(contentsOf: url),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let crop = cg.cropping(to: CGRect(x: column * 307 + 25, y: 595, width: 270, height: 340))
    else { return nil }
    let result = NSImage(cgImage: crop, size: CGSize(width: 270, height: 340))
    Self.portraits[person] = result
    return result
  }
  var body: some View {
    Group {
      if let portrait {
        Image(nsImage: portrait).resizable().scaledToFill()
      } else {
        Image(systemName: "person.crop.square").resizable().scaledToFit().padding(8)
      }
    }.background(Color(red: 0.27, green: 0.29, blue: 0.20)).clipped().accessibilityHidden(true)
  }
}
enum GamePalette {
  static let ink = Color(red: 0.10, green: 0.14, blue: 0.11)
  static let panel = Color(red: 0.13, green: 0.17, blue: 0.13)
  static let paper = Color(red: 0.94, green: 0.89, blue: 0.76)
  static let gold = Color(red: 0.83, green: 0.69, blue: 0.41)
  static let muted = Color(red: 0.72, green: 0.73, blue: 0.63)
}
struct GamePanel<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(18).foregroundStyle(GamePalette.paper)
      .background(GamePalette.panel.opacity(0.97), in: RoundedRectangle(cornerRadius: 6))
      .overlay(
        RoundedRectangle(cornerRadius: 6).stroke(GamePalette.gold.opacity(0.65), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
  }
}

private struct PanelHeight: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
struct GameScroll<Content: View>: View {
  let maximumHeight: CGFloat
  @ViewBuilder var content: Content
  @State private var contentHeight: CGFloat = 120
  var body: some View {
    ScrollView {
      content.frame(maxWidth: .infinity, alignment: .leading)
        .background(
          GeometryReader { geometry in
            Color.clear.preference(key: PanelHeight.self, value: geometry.size.height)
          })
    }.frame(height: min(maximumHeight, contentHeight))
      .onPreferenceChange(PanelHeight.self) { contentHeight = max(1, $0) }
  }
}
