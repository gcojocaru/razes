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

  func rearTexture(index: Int, winter: Bool = false) -> SKTexture? {
    // Shared seasonal crops keep snow, anchors and scale consistent.
    let frames: [CGRect] = [
      CGRect(x: 18, y: 49, width: 329, height: 343),
      CGRect(x: 372, y: 95, width: 351, height: 294),
      CGRect(x: 723, y: 138, width: 343, height: 255),
      CGRect(x: 1077, y: 70, width: 356, height: 330),
      CGRect(x: 37, y: 439, width: 294, height: 307),
      CGRect(x: 362, y: 421, width: 344, height: 328),
      CGRect(x: 724, y: 460, width: 367, height: 287),
      CGRect(x: 1091, y: 422, width: 341, height: 330),
      CGRect(x: 29, y: 763, width: 315, height: 288),
      CGRect(x: 372, y: 782, width: 341, height: 273),
      CGRect(x: 729, y: 826, width: 345, height: 226),
      CGRect(x: 1094, y: 834, width: 334, height: 209),
    ]
    return texture(winter ? "settlement-rear-winter" : "settlement-rear-v2", rect: frames[index])
  }
  func buildingTexture(_ id: BuildingID, level: Int, planned: Bool, winter: Bool, facing: Int = 0)
    -> SKTexture?
  {
    if id == .storehouse {
      return buildingTexture(.granary, level: level, planned: planned, winter: winter, facing: facing)
    }
    if facing >= 2 && !planned {
      let index: [BuildingID: Int] = [
        .woodshed: 1, .cellar: 2, .barn: 3, .well: 4, .granary: 5, .workshop: 6, .bakery: 7,
        .smithy: 8, .stable: 9, .apiary: 10,
      ]
      return rearTexture(index: index[id]!, winter: winter)
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
      .granary: CGRect(x: 32, y: 78, width: 455, height: 410),
      .workshop: CGRect(x: 516, y: 71, width: 510, height: 412),
      .bakery: CGRect(x: 1037, y: 16, width: 487, height: 477),
      .smithy: CGRect(x: 15, y: 494, width: 483, height: 469),
      .stable: CGRect(x: 509, y: 567, width: 532, height: 381),
      .apiary: CGRect(x: 1053, y: 590, width: 462, height: 350),
    ]
    return texture(
      winter ? "settlement-buildings-winter" : "settlement-buildings", rect: frames[id])
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
