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

  private static func rearArtwork(index: Int, winter: Bool) -> (String, CGRect?) {
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
    return (winter ? "settlement-rear-winter" : "settlement-rear-v2", frames[index])
  }
  private static func buildingArtwork(_ id: BuildingID, planned: Bool, winter: Bool, facing: Int)
    -> (String, CGRect?)
  {
    if id == .storehouse {
      return buildingArtwork(.granary, planned: planned, winter: winter, facing: facing)
    }
    if facing >= 2 && !planned {
      let index: [BuildingID: Int] = [
        .woodshed: 1, .cellar: 2, .barn: 3, .well: 4, .granary: 5, .workshop: 6, .bakery: 7,
        .smithy: 8, .stable: 9, .apiary: 10,
      ]
      return rearArtwork(index: index[id]!, winter: winter)
    }
    if id == .woodshed || id == .cellar {
      let name = id.rawValue + "-" + (planned ? "construction" : winter ? "winter" : "complete")
      return (name, individualArtworkFrames[name])
    }
    if id == .barn || id == .well {
      return (
        winter ? "props-winter" : "props",
        id == .barn
          ? CGRect(x: 1107, y: 0, width: 429, height: 503)
          : CGRect(x: 0, y: 503, width: 426, height: 521)
      )
    }
    let frames: [BuildingID: CGRect] = [
      .granary: CGRect(x: 32, y: 78, width: 455, height: 410),
      .workshop: CGRect(x: 516, y: 71, width: 510, height: 412),
      .bakery: CGRect(x: 1037, y: 16, width: 487, height: 477),
      .smithy: CGRect(x: 15, y: 494, width: 483, height: 469),
      .stable: CGRect(x: 509, y: 567, width: 532, height: 381),
      .apiary: CGRect(x: 1053, y: 590, width: 462, height: 350),
    ]
    return (winter ? "settlement-buildings-winter" : "settlement-buildings", frames[id])
  }

  static let individualArtworkFrames: [String: CGRect] = [
    "woodshed-complete": CGRect(x: 32, y: 194, width: 1209, height: 903),
    "woodshed-construction": CGRect(x: 54, y: 192, width: 1163, height: 871),
    "woodshed-winter": CGRect(x: 12, y: 230, width: 1229, height: 873),
    "cellar-complete": CGRect(x: 10, y: 282, width: 1237, height: 744),
    "cellar-construction": CGRect(x: 17, y: 313, width: 1226, height: 646),
    "cellar-winter": CGRect(x: 6, y: 253, width: 1242, height: 845),
  ]

  func rearTexture(index: Int, winter: Bool = false) -> SKTexture? {
    let (name, crop) = Self.rearArtwork(index: index, winter: winter)
    return texture(name, rect: crop)
  }

  func buildingTexture(_ id: BuildingID, level: Int, planned: Bool, winter: Bool, facing: Int = 0)
    -> SKTexture?
  {
    let (name, crop) = Self.buildingArtwork(id, planned: planned, winter: winter, facing: facing)
    return texture(name, rect: crop)
  }

  private static func houseArtwork(level: Int, damaged: Bool, winter: Bool, facing: Int)
    -> (String, CGRect?)
  {
    if level >= 2 {
      let view = facing >= 2 ? "rear" : "front"
      let season = winter ? "winter" : "summer"
      return ("house-upgraded-\(view)-\(season)-\(damaged ? "damaged" : "intact")", nil)
    }
    if facing >= 2 { return rearArtwork(index: 0, winter: winter) }
    return (
      winter ? "props-winter" : "props",
      damaged
        ? CGRect(x: 557, y: 0, width: 550, height: 503)
        : CGRect(x: 0, y: 0, width: 557, height: 503)
    )
  }

  func houseTexture(level: Int, damaged: Bool, winter: Bool, facing: Int = 0) -> SKTexture? {
    let (name, crop) = Self.houseArtwork(
      level: level, damaged: damaged, winter: winter, facing: facing)
    return texture(name, rect: crop)
  }

  static func houseArtworkImage(level: Int, damaged: Bool, winter: Bool, facing: Int = 0)
    -> NSImage?
  {
    let (name, crop) = houseArtwork(level: level, damaged: damaged, winter: winter, facing: facing)
    return artworkImage(name, crop: crop, mirrored: facing % 2 == 1)
  }

  static func buildingArtworkImage(
    _ id: BuildingID, level: Int, planned: Bool, winter: Bool, facing: Int = 0
  ) -> NSImage? {
    let (name, crop) = buildingArtwork(id, planned: planned, winter: winter, facing: facing)
    return artworkImage(name, crop: crop, mirrored: facing % 2 == 1)
  }

  private static var catalogueImages: [String: NSImage] = [:]

  private static func artworkImage(_ name: String, crop: CGRect?, mirrored: Bool) -> NSImage? {
    let key = "\(name)-\(String(describing: crop))-\(mirrored)"
    if let cached = catalogueImages[key] { return cached }
    guard
      let directory = Bundle.module.url(
        forResource: "Art", withExtension: nil, subdirectory: "Resources"),
      let image = NSImage(contentsOf: directory.appendingPathComponent(name + ".png")),
      let original = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { return nil }
    let cgImage: CGImage
    if let crop {
      guard let cropped = original.cropping(to: crop) else { return nil }
      cgImage = cropped
    } else {
      cgImage = original
    }
    let size = CGSize(width: cgImage.width, height: cgImage.height)
    let result = NSImage(cgImage: cgImage, size: size)
    if mirrored {
      let flipped = NSImage(size: size)
      flipped.lockFocus()
      var transform = AffineTransform(scaleByX: -1, byY: 1)
      transform.translate(x: -size.width, y: 0)
      (transform as NSAffineTransform).concat()
      result.draw(in: NSRect(origin: .zero, size: size))
      flipped.unlockFocus()
      catalogueImages[key] = flipped
      return flipped
    }
    catalogueImages[key] = result
    return result
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
