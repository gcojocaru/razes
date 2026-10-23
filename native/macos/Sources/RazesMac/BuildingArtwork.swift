import AppKit
import RazesCore
import SpriteKit

extension HomesteadScene {
  func buildingTexture(_ id: BuildingID, level: Int, planned: Bool, winter: Bool) -> SKTexture? {
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
    progress.isHidden = record?.work == nil
    if let work = record?.work { progress.xScale = 1 - work.remaining / work.duration }
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
    hammer.isHidden = record?.work == nil
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
