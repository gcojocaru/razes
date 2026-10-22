import AppKit
import RazesCore
import SpriteKit

enum Hotspot: String, CaseIterable { case field, house, visitor, stores }
@MainActor final class HomesteadScene: SKScene {
  var onHotspot: ((Hotspot) -> Void)?
  private(set) var resourceWarning: String?
  private var lastState: GameState?
  private var lastReduced = false
  private var textures: [String: SKTexture] = [:]
  private let artDirectory: URL?
  override convenience init() {
    self.init(
      artDirectory: Bundle.module.url(
        forResource: "Art", withExtension: nil, subdirectory: "Resources"))
  }
  init(artDirectory: URL?) {
    self.artDirectory = artDirectory
    super.init(size: CGSize(width: 1200, height: 760))
    scaleMode = .aspectFit
    backgroundColor = NSColor(red: 0.85, green: 0.89, blue: 0.82, alpha: 1)
  }
  required init?(coder: NSCoder) { fatalError("Not used") }
  private func texture(_ name: String, rect: CGRect? = nil) -> SKTexture? {
    if textures[name] == nil {
      guard let url = artDirectory?.appendingPathComponent(name + ".png"),
        let image = NSImage(contentsOf: url)
      else {
        resourceWarning =
          "Some artwork could not load. You can still play using the household controls."
        return nil
      }
      textures[name] = SKTexture(image: image)
    }
    let base = textures[name]!
    guard let r = rect else { return base }
    let size = base.size()
    return SKTexture(
      rect: CGRect(
        x: r.minX / size.width, y: 1 - r.maxY / size.height, width: r.width / size.width,
        height: r.height / size.height), in: base)
  }
  @discardableResult private func sprite(
    _ name: String, rect: CGRect? = nil, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
    bottom: Bool = true
  ) -> SKSpriteNode {
    let node = SKSpriteNode(texture: texture(name, rect: rect))
    node.size = CGSize(width: width, height: height)
    node.anchorPoint = CGPoint(x: 0.5, y: bottom ? 0 : 0.5)
    node.position = CGPoint(x: x, y: 760 - y)
    addChild(node)
    return node
  }
  func update(state s: GameState, reducedMotion: Bool) {
    guard s != lastState || reducedMotion != lastReduced else { return }
    lastState = s
    lastReduced = reducedMotion
    removeAllChildren()
    let p = Presentation(state: s)
    sprite(Content.seasons[s.season].lowercased(), x: 600, y: 760, width: 1200, height: 760)
    let crops = ["bare", "sown", "growing", "ripe", "harvested", "snow"]
    let i = crops.firstIndex(of: p.field)!
    sprite(
      "fields", rect: CGRect(x: (i % 3) * 525, y: (i / 3) * 499, width: 525, height: 499), x: 285,
      y: 640, width: 390, height: 295)
    let atlas = s.season == 3 ? "props-winter" : "props"
    sprite(
      atlas, rect: CGRect(x: 1107, y: 0, width: 429, height: 503), x: 370, y: 452, width: 215,
      height: 235)
    sprite(
      atlas,
      rect: p.house == "intact"
        ? CGRect(x: 0, y: 0, width: 557, height: 503)
        : CGRect(x: 557, y: 0, width: 550, height: 503), x: 700, y: 493, width: 355, height: 320)
    sprite(
      atlas, rect: CGRect(x: 0, y: 503, width: 426, height: 521), x: 956, y: 552, width: 125,
      height: 153)
    for j in 0..<p.stores {
      sprite(
        atlas, rect: CGRect(x: 426, y: 503, width: 634, height: 521), x: j == 0 ? 408 : 482,
        y: j == 0 ? 524 : 545, width: j == 0 ? 116 : 107, height: j == 0 ? 96 : 88)
    }
    let positions: [TaskID: CGPoint] = [
      .plant: CGPoint(x: 245, y: 569), .tend: CGPoint(x: 245, y: 569),
      .harvest: CGPoint(x: 245, y: 569), .repair: CGPoint(x: 720, y: 510),
      .paid: CGPoint(x: 903, y: 643), .help: CGPoint(x: 824, y: 582),
      .supplies: CGPoint(x: 430, y: 547), .rest: CGPoint(x: 645, y: 552),
    ]
    for j in 0..<4 {
      if j == 3 && p.visitor == nil { continue }
      let task = j < 3 ? s.assignments[WorkerID.allCases[j].rawValue]! : .rest
      let pos = j < 3 ? (positions[task] ?? positions[.rest]!) : CGPoint(x: 827, y: 554)
      let frame = j < 3 ? j : p.visitor == "dumitru" ? 4 : 3
      let x = pos.x + (j == 1 ? 35 : j == 2 ? -29 : 0)
      let y = pos.y + (j < 3 ? CGFloat(j * 8) : 0)
      let person = sprite(
        "people", rect: CGRect(x: frame * 307, y: 0, width: 307, height: 590), x: x, y: y,
        width: 48, height: 92)
      if !reducedMotion {
        person.run(
          .repeatForever(
            .sequence([.scaleY(to: 1.012, duration: 1.4), .scaleY(to: 1, duration: 1.4)])))
      }
      if [.plant, .tend, .harvest, .repair].contains(task) && j < 3 {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 2, y: 27))
        path.move(to: CGPoint(x: -7, y: 27))
        path.addLine(to: CGPoint(x: 10, y: 27))
        let tool = SKShapeNode(path: path)
        tool.strokeColor = .brown
        tool.lineWidth = 3
        tool.position = CGPoint(x: x + 15, y: 760 - y + 28)
        addChild(tool)
        if !reducedMotion && s.phase == .consequence {
          tool.run(
            .repeatForever(
              .sequence([
                .rotate(toAngle: 0.35, duration: 0.35), .rotate(toAngle: -0.35, duration: 0.35),
              ])))
        }
      }
    }
    sprite(
      atlas, rect: CGRect(x: 1066, y: 503, width: 470, height: 521), x: 1040, y: 712, width: 275,
      height: 235)
    if !reducedMotion {
      let snow = p.weather == "snow"
      let rain = p.weather == "rain"
      for j in 0..<(snow || rain ? 48 : 20) {
        let particle = SKShapeNode(ellipseOf: CGSize(width: rain ? 1.5 : 4, height: rain ? 17 : 4))
        particle.fillColor =
          snow
          ? .white
          : rain ? NSColor.lightGray : NSColor(red: 0.91, green: 0.78, blue: 0.49, alpha: 1)
        particle.strokeColor = .clear
        particle.alpha = 0.65
        particle.position = CGPoint(x: (j * 137) % 1200, y: (j * 83) % 760)
        addChild(particle)
        let duration: TimeInterval = rain ? 2.6 : snow ? 25 : 38
        particle.run(
          .repeatForever(
            .sequence([
              .moveBy(x: 80, y: -800, duration: duration), .moveBy(x: -80, y: 800, duration: 0),
            ])))
      }
      for j in 0..<5 {
        let smoke = SKShapeNode(ellipseOf: CGSize(width: 15 + j * 6, height: 9 + j * 4))
        smoke.fillColor = .white
        smoke.strokeColor = .clear
        smoke.alpha = 0.17
        smoke.position = CGPoint(x: 733 + j * 4, y: 524 + j * 11)
        addChild(smoke)
        smoke.run(
          .repeatForever(
            .sequence([
              .group([.moveBy(x: 30, y: 65, duration: 5.5), .fadeOut(withDuration: 5.5)]),
              .moveBy(x: -30, y: -65, duration: 0), .fadeAlpha(to: 0.17, duration: 0),
            ])))
      }
    }
  }
  override func mouseDown(with event: NSEvent) {
    let point = event.location(in: self)
    let zones: [(Hotspot, CGRect)] = [
      (.field, CGRect(x: 110, y: 125, width: 350, height: 180)),
      (.house, CGRect(x: 535, y: 270, width: 330, height: 250)),
      (.visitor, CGRect(x: 787, y: 156, width: 80, height: 100)),
      (.stores, CGRect(x: 365, y: 212, width: 140, height: 100)),
    ]
    if let spot = zones.first(where: { $0.1.contains(point) })?.0 { onHotspot?(spot) }
  }
}
