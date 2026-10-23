import AppKit
import RazesCore
import SpriteKit

extension HomesteadScene {
  func mirroredTexture(_ base: SKTexture) -> SKTexture {
    let key = ObjectIdentifier(base)
    if let cached = mirroredTextures[key] { return cached }
    let image = NSImage(size: base.size())
    image.lockFocus()
    let transform = AffineTransform(scaleByX: -1, byY: 1)
    var mirror = transform
    mirror.translate(x: -base.size().width, y: 0)
    (mirror as NSAffineTransform).concat()
    NSImage(cgImage: base.cgImage(), size: base.size()).draw(
      in: NSRect(origin: .zero, size: base.size()))
    image.unlockFocus()
    let result = SKTexture(image: image)
    mirroredTextures[key] = result
    return result
  }

  func rearTexture(index: Int) -> SKTexture? {
    let frames: [CGRect] = [
      CGRect(x: 24, y: 51, width: 333, height: 354),
      CGRect(x: 379, y: 101, width: 333, height: 304),
      CGRect(x: 732, y: 163, width: 324, height: 241),
      CGRect(x: 1071, y: 73, width: 356, height: 342),
      CGRect(x: 40, y: 447, width: 299, height: 315),
      CGRect(x: 345, y: 423, width: 349, height: 352),
      CGRect(x: 719, y: 471, width: 359, height: 304),
      CGRect(x: 1091, y: 429, width: 329, height: 339),
      CGRect(x: 29, y: 761, width: 317, height: 317),
      CGRect(x: 357, y: 790, width: 350, height: 291),
      CGRect(x: 722, y: 847, width: 347, height: 234),
      CGRect(x: 1093, y: 846, width: 324, height: 229),
    ]
    return texture("settlement-rear", rect: frames[index])
  }
  func buildingTexture(_ id: BuildingID, level: Int, planned: Bool, winter: Bool, facing: Int = 0)
    -> SKTexture?
  {
    if facing >= 2 {
      let index: [BuildingID: Int] = [
        .woodshed: 1, .cellar: 2, .barn: 3, .well: 4, .granary: 5, .workshop: 6, .bakery: 7,
        .smithy: 8, .stable: 9, .apiary: 10,
      ]
      return rearTexture(index: index[id]!)
    }
    if id == .woodshed || id == .cellar {
      return texture(
        id.rawValue + "-" + (planned ? "construction" : winter ? "winter" : "complete"))
    }
    if id == .barn || id == .well {
      return texture(
        winter ? "props-winter" : "props",
        rect: id == .barn
          ? CGRect(x: 1107, y: 0, width: 429, height: 503)
          : CGRect(x: 0, y: 503, width: 426, height: 521))
    }
    let frames: [BuildingID: CGRect] = [
      .granary: CGRect(x: 34, y: 86, width: 451, height: 393),
      .workshop: CGRect(x: 518, y: 77, width: 506, height: 392),
      .bakery: CGRect(x: 1039, y: 18, width: 483, height: 461),
      .smithy: CGRect(x: 17, y: 510, width: 479, height: 436),
      .stable: CGRect(x: 512, y: 580, width: 523, height: 350),
      .apiary: CGRect(x: 1055, y: 602, width: 458, height: 336),
    ]
    return texture("settlement-buildings", rect: frames[id])
  }

  func updateBuildingLayers(_ node: SKSpriteNode, record: BuildingRecord?, stage: BuildingStage) {
    if node.childNode(withName: "level-badge") == nil {
      let badge = SKLabelNode(fontNamed: "DMSans9pt-Regular")
      badge.name = "level-badge"
      badge.fontSize = 13
      badge.fontColor = .white
      badge.zPosition = 10
      node.addChild(badge)
      for (name, color, y) in [
        ("condition-track", NSColor.black.withAlphaComponent(0.6), CGFloat(-9)),
        ("condition-fill", NSColor.systemGreen, CGFloat(-9)),
        ("work-progress", NSColor.systemYellow, CGFloat(-17)),
      ] {
        let bar = SKSpriteNode(color: color, size: CGSize(width: 66, height: 3))
        bar.name = name
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        bar.position = CGPoint(x: -33, y: y)
        bar.zPosition = 10
        node.addChild(bar)
      }
      for level in 2...5 {
        let addon = SKSpriteNode(
          texture: texture("props", rect: CGRect(x: 426, y: 503, width: 634, height: 521)))
        addon.name = "upgrade-\(level)"
        addon.anchorPoint = CGPoint(x: 0.5, y: 0)
        addon.size = CGSize(width: 30, height: 25)
        addon.position = CGPoint(x: CGFloat((level - 2) * 18 - 60), y: 6)
        node.addChild(addon)
      }

      let damage = SKShapeNode()
      damage.name = "wear-marks"
      damage.strokeColor = .darkGray
      damage.lineWidth = 2
      damage.zPosition = 5
      node.addChild(damage)
      let hammer = SKLabelNode(fontNamed: "DMSans9pt-Regular")
      hammer.name = "work-indicator"
      hammer.text = "⚒"
      hammer.fontSize = 24
      hammer.fontColor = .systemYellow
      hammer.zPosition = 10
      node.addChild(hammer)
    }
    let level = record?.level ?? 0
    let badge = node.childNode(withName: "level-badge") as! SKLabelNode
    badge.text = level == 0 ? "FOUNDATION" : "L\(level) / 5"
    badge.position = CGPoint(x: 0, y: node.size.height + 8)
    badge.isHidden = stage == .empty
    let condition = record?.condition ?? 100
    node.childNode(withName: "condition-track")?.isHidden = record == nil
    let fill = node.childNode(withName: "condition-fill") as! SKSpriteNode
    fill.xScale = condition / 100
    fill.color = condition < 30 ? .systemOrange : .systemGreen
    fill.isHidden = record == nil
    let progress = node.childNode(withName: "work-progress") as! SKSpriteNode
    progress.isHidden = record?.level != 0
    progress.xScale = 1
    for value in 2...5 { node.childNode(withName: "upgrade-\(value)")?.isHidden = level < value }
    let damage = node.childNode(withName: "wear-marks") as! SKShapeNode
    damage.isHidden = condition >= 60
    let path = CGMutablePath()
    path.addLines(between: [
      CGPoint(x: -30, y: 42), CGPoint(x: -24, y: 34), CGPoint(x: -30, y: 26),
      CGPoint(x: -17, y: 18),
    ])
    damage.path = path
    let hammer = node.childNode(withName: "work-indicator")!
    hammer.position = CGPoint(x: 45, y: node.size.height * 0.65)
    hammer.isHidden = record?.level != 0
    if reduced || hammer.isHidden {
      hammer.removeAllActions()
      hammer.alpha = 1
    } else if !hammer.hasActions() {
      hammer.run(
        .repeatForever(
          .sequence([.fadeAlpha(to: 0.35, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
    }
  }
}
