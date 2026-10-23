import AppKit
import RazesCore
import SpriteKit

@MainActor final class HomesteadScene: SKScene {
  var onSelection: ((SceneSelection) -> Void)?
  private(set) var resourceWarning: String?
  private(set) var completionEffectCount = 0
  private(set) var previous: GameState?
  private(set) var reduced = false
  private var selection: SceneSelection?
  private var buildMode = false
  private let artDirectory: URL?
  private var textures: [String: SKTexture] = [:]
  var mirroredTextures: [ObjectIdentifier: SKTexture] = [:]
  private var sprites: [String: SKSpriteNode] = [:]
  private let backdrop = SKNode(), terrain = SKNode(), world = SKNode()
  private let ground = TerrainLayer()
  var infrastructureSignature: InfrastructureSignature?
  var infrastructureNodes: [String: SKNode] = [:]
  var pavementTexture: SKTexture?
  private let weather = SKNode(), smoke = SKNode(), markers = SKNode(), feedback = SKNode()
  private var weatherSignature = ""
  private var workerPositions: [WorkerID: CGPoint] = [:]
  let navigationCamera = SKCameraNode(), placementOverlay = SKNode()
  var cameraState = CameraState()
  var onCameraChange: ((Int) -> Void)?
  var placementTool: PlacementTool? {
    didSet { if placementTool != oldValue { lastPainted = nil } }
  }
  var placementFacing = 0 {
    didSet { if placementFacing != oldValue { lastPainted = nil } }
  }
  private var lastPainted: GridPosition?
  var onPlacement: ((PlacementTool, GridPosition) -> Void)?
  var dragStart: CGPoint?, dragLast: CGPoint?, dragged = false
  var lastPointer = IsometricLayout.house
  static let plotSizes: [BuildingID: CGSize] = Dictionary(
    uniqueKeysWithValues: BuildingID.allCases.map {
      (
        $0,
        $0 == .well
          ? CGSize(width: 100, height: 130)
          : $0 == .cellar ? CGSize(width: 180, height: 120) : CGSize(width: 185, height: 150)
      )
    })
  override convenience init() {
    self.init(
      artDirectory: Bundle.module.url(
        forResource: "Art", withExtension: nil, subdirectory: "Resources"))
  }
  init(artDirectory: URL?) {
    self.artDirectory = artDirectory
    super.init(size: CGSize(width: 1200, height: 760))
    navigationCamera.name = "camera"
    addChild(navigationCamera)
    camera = navigationCamera
    placementOverlay.name = "placement"
    placementOverlay.zPosition = 2060
    addChild(placementOverlay)
    applyCamera()
    scaleMode = .aspectFit
    backgroundColor = NSColor(red: 0.13, green: 0.17, blue: 0.13, alpha: 1)
    backdrop.name = "backdrop"
    addChild(backdrop)
    terrain.name = "terrain"
    terrain.zPosition = 5
    addChild(terrain)
    terrain.addChild(ground)
    world.name = "world"
    world.zPosition = 100
    addChild(world)
    weather.name = "weather"
    weather.zPosition = 2000
    addChild(weather)
    smoke.name = "smoke"
    smoke.zPosition = 1900
    addChild(smoke)
    markers.name = "selection"
    markers.zPosition = 2050
    addChild(markers)
    feedback.name = "feedback"
    feedback.zPosition = 2100
    addChild(feedback)
  }
  required init?(coder: NSCoder) { fatalError("Not used") }
  func texture(_ name: String, rect: CGRect? = nil) -> SKTexture? {
    if textures[name] == nil {
      guard let url = artDirectory?.appendingPathComponent(name + ".png"),
        let image = NSImage(contentsOf: url)
      else {
        resourceWarning = "Some artwork could not load. The command controls remain available."
        return nil
      }
      textures[name] = SKTexture(image: image)
    }
    let base = textures[name]!
    let frames: [String: CGRect] = [
      "woodshed-complete": CGRect(x: 32, y: 194, width: 1209, height: 903),
      "woodshed-construction": CGRect(x: 54, y: 192, width: 1163, height: 871),
      "woodshed-winter": CGRect(x: 12, y: 230, width: 1229, height: 873),
      "cellar-complete": CGRect(x: 10, y: 282, width: 1237, height: 744),
      "cellar-construction": CGRect(x: 17, y: 313, width: 1226, height: 646),
      "cellar-winter": CGRect(x: 6, y: 253, width: 1242, height: 845),
    ]
    guard let rect = rect ?? frames[name] else { return base }
    let size = base.size()
    let key = "\(name)-crop-\(rect)"
    if let cached = textures[key] { return cached }
    let cropped = SKTexture(
      rect: CGRect(
        x: rect.minX / size.width, y: 1 - rect.maxY / size.height, width: rect.width / size.width,
        height: rect.height / size.height), in: base)
    textures[key] = cropped
    return cropped
  }
  @discardableResult private func sprite(
    _ id: String, art: String, crop: CGRect? = nil, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
    z: CGFloat
  ) -> SKSpriteNode {
    let node: SKSpriteNode
    if let existing = sprites[id] {
      node = existing
    } else {
      node = SKSpriteNode()
      node.name = id
      node.anchorPoint = CGPoint(x: 0.5, y: 0)
      sprites[id] = node
      (id == "land" ? backdrop : world).addChild(node)
    }
    node.texture = texture(art, rect: crop)
    node.color = .clear
    let height =
      art.hasPrefix("woodshed-") || art.hasPrefix("cellar-")
      ? w * (node.texture?.size().height ?? h) / max(1, node.texture?.size().width ?? w) : h
    node.size = CGSize(width: w, height: height)
    let point = CGPoint(x: x, y: 760 - y)
    node.position = id == "land" ? point : projected(point)
    node.zPosition =
      id == "land"
      ? z : 1000 - node.position.y + (id.hasPrefix("worker-") || id == "visitor" ? 10 : 0)
    node.isHidden = false
    return node
  }
  @discardableResult private func isoSprite(
    _ id: String, art: String, crop: CGRect? = nil, point: CGPoint, width: CGFloat, height: CGFloat
  ) -> SKSpriteNode {
    sprite(
      id, art: art, crop: crop, x: point.x, y: 760 - point.y, w: width, h: height, z: 1000 - point.y
    )
  }
  func update(state s: GameState, reducedMotion: Bool, animateChanges: Bool = true) {
    guard previous != s || reduced != reducedMotion else { return }
    let old = previous
    let motionChanged = reduced != reducedMotion
    previous = s
    reduced = reducedMotion
    let p = Presentation(state: s)
    let atlas = s.displaySeason == 3 ? "props-winter" : "props"
    let land = sprite(
      "land", art: Content.seasons[s.displaySeason].lowercased(), x: 600, y: 1760, w: 4000, h: 2500,
      z: 0)
    land.color = NSColor(red: 0.10, green: 0.18, blue: 0.13, alpha: 1)
    land.colorBlendFactor = 0.68
    ground.update(state: s) { texture($0) }
    let fields = ["bare", "sown", "growing", "ripe", "harvested", "snow"]
    let i = fields.firstIndex(of: p.field)!
    isoSprite(
      "field", art: "fields",
      crop: CGRect(x: (i % 3) * 525, y: (i / 3) * 499, width: 525, height: 499),
      point: IsometricLayout.field, width: 290, height: 185)
    sprites["field"]?.isHidden = !s.planted && !s.assignments.values.contains(.plant)
    isoSprite(
      "house", art: atlas,
      crop: p.house == "intact"
        ? CGRect(x: 0, y: 0, width: 557, height: 503)
        : CGRect(x: 557, y: 0, width: 550, height: 503), point: IsometricLayout.house, width: 240,
      height: 216)
    let houseNode = sprites["house"]!
    if s.layout.viewRotation >= 2 {
      houseNode.texture = rearTexture(index: 0, winter: s.displaySeason == 3)
      if let texture = houseNode.texture {
        houseNode.size.height = houseNode.size.width * texture.size().height / texture.size().width
      }
    }
    houseNode.xScale = s.layout.viewRotation % 2 == 0 ? 1 : -1
    let currentScenery = Set(s.layout.scenery.map { "scenery-" + $0.id })
    for id in Array(sprites.keys) where id.hasPrefix("scenery-") && !currentScenery.contains(id) {
      sprites.removeValue(forKey: id)?.removeFromParent()
    }
    for scenery in s.layout.scenery {
      let crop: CGRect
      let width: CGFloat
      let height: CGFloat
      switch scenery.kind {
      case .barn:
        crop = CGRect(x: 1107, y: 0, width: 429, height: 503)
        width = 160
        height = 170
      case .well:
        crop = CGRect(x: 0, y: 503, width: 426, height: 521)
        width = 80
        height = 98
      case .stores:
        crop = CGRect(x: 426, y: 503, width: 634, height: 521)
        width = 85
        height = 70
      case .fence:
        crop = CGRect(x: 1066, y: 503, width: 470, height: 521)
        width = 160
        height = 110
      }
      let sceneryNode = isoSprite(
        "scenery-" + scenery.id, art: atlas, crop: crop,
        point: IsometricLayout.center(
          scenery.position, kind: .scenery(scenery.kind), facing: scenery.facing), width: width,
        height: height)
      let facing = (scenery.facing + s.layout.viewRotation) % 4
      if facing >= 2, scenery.kind != .fence {
        sceneryNode.texture = rearTexture(
          index: scenery.kind == .barn ? 3 : scenery.kind == .well ? 4 : 11,
          winter: s.displaySeason == 3)
        if let texture = sceneryNode.texture {
          sceneryNode.size.height = width * texture.size().height / texture.size().width
        }
      }
      sceneryNode.xScale = facing % 2 == 0 ? 1 : -1
    }
    for id in BuildingID.allCases {
      let stage = Construction.stage(id, state: s)
      let point = IsometricLayout.plot(id, state: s)
      let pos = CGPoint(x: point.x, y: 760 - point.y)
      let size = Self.plotSizes[id]!
      let record = s.buildings.first { $0.id == id }
      let node: SKSpriteNode
      if let existing = sprites["plot-\(id.rawValue)"] {
        node = existing
      } else {
        node = SKSpriteNode()
        node.name = "plot-\(id.rawValue)"
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprites["plot-\(id.rawValue)"] = node
        world.addChild(node)
      }
      node.texture = buildingTexture(
        id, level: record?.level ?? 0, planned: stage == .planned, winter: s.displaySeason == 3,
        facing: ((s.layout.buildings.first { $0.id == id }?.facing ?? 0) + s.layout.viewRotation)
          % 4)
      let textureSize = node.texture?.size() ?? size
      node.size = CGSize(
        width: size.width, height: size.width * textureSize.height / max(1, textureSize.width))
      node.position = projected(CGPoint(x: pos.x, y: 760 - pos.y))
      node.zPosition = 1000 - node.position.y
      node.color = .brown
      node.colorBlendFactor = record?.condition == 0 ? 0.45 : stage == .planned ? 0.25 : 0
      let facing =
        ((s.layout.buildings.first { $0.id == id }?.facing ?? 0) + s.layout.viewRotation) % 4
      // Texture mirroring keeps labels, condition bars and upgrade layers upright.
      if facing % 2 == 1, let base = node.texture { node.texture = mirroredTexture(base) }
      updateBuildingLayers(node, record: record, stage: stage)
      node.isHidden =
        stage == .empty && (!buildMode || Settlement.position(for: id, in: s.layout) == nil)
      node.alpha = stage == .empty ? 0.38 : 1
      if stage == .complete && old != nil
        && !old!.buildings.contains(where: { $0.id == id && $0.level >= (record?.level ?? 1) })
        && !reduced && animateChanges
      {
        completionEffectCount += 1
        let flash = SKShapeNode(ellipseOf: CGSize(width: size.width, height: 35))
        flash.strokeColor = .init(red: 0.96, green: 0.83, blue: 0.51, alpha: 1)
        flash.lineWidth = 3
        flash.position = node.position
        feedback.addChild(flash)
        flash.run(
          .sequence([
            .group([.scale(to: 1.25, duration: 0.7), .fadeOut(withDuration: 0.7)]),
            .removeFromParent(),
          ]))
      }
    }
    for (j, worker) in WorkerID.allCases.enumerated() {
      let task = s.assignments[worker.rawValue]!
      let pos = IsometricLayout.worker(task, state: s)
      let x = pos.x + (j == 1 ? 26 : j == 2 ? -22 : 0)
      let y = 760 - pos.y + CGFloat(j * 5)
      let groundPoint = projected(CGPoint(x: x, y: 760 - y))
      let moved = workerPositions[worker] != groundPoint
      workerPositions[worker] = groundPoint
      let person = sprite(
        "worker-\(worker.rawValue)", art: "people",
        crop: CGRect(x: j * 307, y: 0, width: 307, height: 590), x: x, y: y, w: 34, h: 65,
        z: 1000 - (760 - y) + 10)
      if old?.assignments[worker.rawValue] != task || old?.phase != s.phase || old == nil
        || motionChanged || moved || reduced
      {
        person.removeAllActions()
        person.zRotation = 0
        person.yScale = 1
      }
      if !reduced && !person.hasActions() {
        person.run(
          .repeatForever(
            .sequence([.scaleY(to: 1.012, duration: 1.4), .scaleY(to: 1, duration: 1.4)])))
      }
      if old?.assignments[worker.rawValue] != task || old?.phase != s.phase || old == nil
        || motionChanged || moved
      {
        updateTool(
          worker: worker, task: task, point: CGPoint(x: groundPoint.x + 15, y: groundPoint.y + 28),
          phase: s.phase,
          depth: person.zPosition + 1)
      }
    }
    let visitor = sprite(
      "visitor", art: "people",
      crop: CGRect(x: (p.visitor == "dumitru" ? 4 : 3) * 307, y: 0, width: 307, height: 590),
      x: IsometricLayout.visitor.x, y: 760 - IsometricLayout.visitor.y, w: 34, h: 65,
      z: 1010 - IsometricLayout.visitor.y)
    visitor.isHidden = p.visitor == nil
    updateInfrastructure(state: s)
    updateWeather(p.weather)
    if let old, animateChanges && !reduced && old.revision != s.revision {
      let changes = [
        ("Food", s.food - old.food), ("Money", s.money - old.money),
        ("Shelter", s.house - old.house),
      ].filter { $0.1 != 0 }
      for (index, change) in changes.enumerated() {
        let text = SKLabelNode(fontNamed: "DMSans9pt-Regular")
        text.fontSize = 18 * cameraState.scale
        text.fontColor = .white
        text.name = "resource-feedback"
        text.text = "\(change.0) \(change.1 > 0 ? "+":"")\(change.1)"
        text.position = CGPoint(
          x: cameraState.center.x + CGFloat(index - 1) * 130 * cameraState.scale,
          y: cameraState.center.y + (size.height / 2 - 105) * cameraState.scale)
        feedback.addChild(text)
        text.run(
          .sequence([
            .group([.moveBy(x: 0, y: 18, duration: 1.6), .fadeOut(withDuration: 1.6)]),
            .removeFromParent(),
          ]))
      }
    }
    if reduced { feedback.removeAllChildren() }
    drawSelection()
    updatePlacement(at: lastPointer)
    applyCamera()
  }
  private func updateTool(
    worker: WorkerID, task: TaskID, point: CGPoint, phase: Phase, depth: CGFloat
  ) {
    let name = "tool-\(worker.rawValue)"
    let dustName = "dust-\(worker.rawValue)"
    world.childNode(withName: name)?.removeFromParent()
    world.childNode(withName: dustName)?.removeFromParent()
    guard [.plant, .tend, .harvest, .repair, .buildWoodshed, .buildCellar].contains(task) else {
      return
    }
    let path = CGMutablePath()
    path.move(to: .zero)
    path.addLine(to: CGPoint(x: 2, y: 27))
    path.move(to: CGPoint(x: -7, y: 27))
    path.addLine(to: CGPoint(x: 10, y: 27))
    let tool = SKShapeNode(path: path)
    tool.name = name
    tool.strokeColor = .brown
    tool.lineWidth = 3
    tool.position = point
    tool.zPosition = depth
    world.addChild(tool)
    guard !reduced && (phase == .work || phase == .consequence) else { return }
    tool.run(
      .repeatForever(
        .sequence([.rotate(toAngle: 0.3, duration: 0.4), .rotate(toAngle: -0.3, duration: 0.4)])))
    if Construction.building(for: task) != nil {
      let dust = SKNode()
      dust.name = dustName
      dust.position = CGPoint(x: point.x, y: point.y - 25)
      dust.zPosition = depth + 1
      world.addChild(dust)
      for index in 0..<5 {
        let particle = SKShapeNode(ellipseOf: CGSize(width: 5 + index, height: 3 + index))
        particle.fillColor = NSColor(red: 0.72, green: 0.59, blue: 0.40, alpha: 1)
        particle.strokeColor = .clear
        particle.alpha = 0
        dust.addChild(particle)
        particle.run(
          .repeatForever(
            .sequence([
              .wait(forDuration: Double(index) * 0.13), .fadeAlpha(to: 0.3, duration: 0.12),
              .group([
                .moveBy(x: CGFloat(index * 3 - 6), y: 12, duration: 0.7),
                .fadeOut(withDuration: 0.7),
              ]), .move(to: .zero, duration: 0), .wait(forDuration: 0.8),
            ])))
      }
    }
  }
  private func updateWeather(_ kind: String) {
    let signature = "\(kind)-\(reduced)-\(previous?.layout.viewRotation ?? 0)"
    guard signature != weatherSignature else { return }
    weatherSignature = signature
    weather.removeAllChildren()
    smoke.removeAllChildren()
    guard !reduced else { return }
    let rain = kind == "rain"
    let snow = kind == "snow"
    for j in 0..<(rain || snow ? 48 : 20) {
      let particle = SKShapeNode(ellipseOf: CGSize(width: rain ? 1.5 : 4, height: rain ? 17 : 4))
      particle.fillColor =
        snow ? .white : rain ? .lightGray : NSColor(red: 0.95, green: 0.84, blue: 0.58, alpha: 1)
      particle.strokeColor = .clear
      particle.alpha = 0.6
      particle.position = CGPoint(x: (j * 137) % 1200, y: (j * 83) % 760)
      weather.addChild(particle)
      let duration: TimeInterval = rain ? 2.6 : snow ? 25 : 38
      particle.run(
        .repeatForever(
          .sequence([
            .moveBy(x: 80, y: -800, duration: duration), .moveBy(x: -80, y: 800, duration: 0),
          ])))
    }
    for j in 0..<5 {
      let node = SKShapeNode(ellipseOf: CGSize(width: 15 + j * 6, height: 9 + j * 4))
      node.fillColor = .white
      node.strokeColor = .clear
      node.alpha = 0.17
      node.position = CGPoint(
        x: projected(IsometricLayout.house).x
          + [CGFloat(64), -64, -64, 64][previous?.layout.viewRotation ?? 0] + CGFloat(j * 4),
        y: projected(IsometricLayout.house).y + 197 + CGFloat(j * 11))
      smoke.addChild(node)
      node.run(
        .repeatForever(
          .sequence([
            .group([.moveBy(x: 30, y: 65, duration: 5.5), .fadeOut(withDuration: 5.5)]),
            .moveBy(x: -30, y: -65, duration: 0), .fadeAlpha(to: 0.17, duration: 0),
          ])))
    }
  }
  func select(_ selection: SceneSelection?, buildMode: Bool) {
    self.selection = selection
    self.buildMode = buildMode
    if let s = previous {
      for id in BuildingID.allCases where Construction.stage(id, state: s) == .empty {
        sprites["plot-\(id.rawValue)"]?.isHidden =
          !buildMode || Settlement.position(for: id, in: s.layout) == nil
        sprites["plot-\(id.rawValue)"]?.alpha = 0.38
      }
    }
    drawSelection()
  }
  private func marker(at point: CGPoint, width: CGFloat, label: String) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: width / 4))
    path.addLine(to: CGPoint(x: width / 2, y: 0))
    path.addLine(to: CGPoint(x: 0, y: -width / 4))
    path.addLine(to: CGPoint(x: -width / 2, y: 0))
    path.closeSubpath()
    let outline = SKShapeNode(path: path)
    outline.position = projected(point)
    outline.strokeColor = .init(red: 0.95, green: 0.82, blue: 0.46, alpha: 1)
    outline.lineWidth = 2
    outline.fillColor = .clear
    markers.addChild(outline)
    let text = SKLabelNode(fontNamed: "DMSans9pt-Regular")
    text.text = label
    text.fontSize = 14
    text.fontColor = .white
    text.position = CGPoint(x: projected(point).x, y: projected(point).y - width / 4 - 20)
    markers.addChild(text)
  }
  private func drawSelection() {
    markers.removeAllChildren()
    if buildMode {
      for column in 0..<Settlement.size {
        for row in 0..<Settlement.size {
          let center = IsometricLayout.point(
            column: CGFloat(column), row: CGFloat(row), rotation: previous?.layout.viewRotation ?? 0
          )
          let path = CGMutablePath()
          path.move(to: CGPoint(x: 0, y: 33))
          path.addLine(to: CGPoint(x: 66, y: 0))
          path.addLine(to: CGPoint(x: 0, y: -33))
          path.addLine(to: CGPoint(x: -66, y: 0))
          path.closeSubpath()
          let tile = SKShapeNode(path: path)
          tile.position = center
          tile.strokeColor = NSColor(red: 0.93, green: 0.84, blue: 0.60, alpha: 0.18)
          tile.lineWidth = 0.7
          tile.fillColor = .clear
          markers.addChild(tile)
        }
      }
    }
    if buildMode {
      for id in BuildingID.allCases {
        guard let state = previous, Settlement.position(for: id, in: state.layout) != nil else {
          continue
        }
        let p = IsometricLayout.plot(id, state: state)
        marker(
          at: p, width: Self.plotSizes[id]!.width,
          label: Construction.definition(id).title)
      }
    }
    switch selection {
    case .worker(let id):
      if let p = workerPositions[id] {
        marker(at: unprojected(p), width: 70, label: Content.shared.people[id.rawValue]!.name)
      }
    case .building(let id):
      if !buildMode {
        let p = IsometricLayout.plot(id, state: previous)
        marker(
          at: p, width: Self.plotSizes[id]!.width,
          label: Construction.definition(id).title)
      }
    case .hotspot(let spot):
      let points: [Hotspot: CGPoint] = [
        .field: IsometricLayout.field, .house: IsometricLayout.house,
        .stores: IsometricLayout.stores, .visitor: IsometricLayout.visitor,
      ]
      marker(at: points[spot]!, width: spot == .field ? 200 : 100, label: spot.rawValue.capitalized)
    case .scenery(let id):
      if let node = sprites["scenery-" + id] {
        marker(
          at: unprojected(node.position), width: 100,
          label: previous?.layout.scenery.first(where: { $0.id == id })?.kind.rawValue.capitalized
            ?? "Scenery")
      }
    case nil: break
    }
  }
  func selection(at point: CGPoint) -> SceneSelection? {
    var targets: [(SKSpriteNode, SceneSelection)] = []
    for worker in WorkerID.allCases {
      if let node = sprites["worker-\(worker.rawValue)"] { targets.append((node, .worker(worker))) }
    }
    for id in BuildingID.allCases {
      if let node = sprites["plot-\(id.rawValue)"] { targets.append((node, .building(id))) }
    }
    for (spot, id) in [
      (Hotspot.visitor, "visitor"), (.stores, "store-0"), (.stores, "store-1"), (.house, "house"),
      (.field, "field"),
    ] {
      if let node = sprites[id] { targets.append((node, .hotspot(spot))) }
    }
    for scenery in previous?.layout.scenery ?? [] {
      if let node = sprites["scenery-" + scenery.id] {
        targets.append((node, .scenery(scenery.id)))
      }
    }
    return targets.filter { !$0.0.isHidden && $0.0.frame.contains(point) }
      .max { $0.0.zPosition < $1.0.zPosition }?.1
  }
  override func didMove(to view: SKView) {
    view.window?.acceptsMouseMovedEvents = true
    applyCamera()
  }
  override func mouseDown(with event: NSEvent) {
    if case .infrastructure = placementTool {
      lastPainted = nil
      paintInfrastructure(event.location(in: self))
    } else {
      beginPan(event)
    }
  }
  override func mouseDragged(with event: NSEvent) {
    if case .infrastructure = placementTool {
      paintInfrastructure(event.location(in: self))
    } else {
      continuePan(event)
    }
  }
  override func mouseUp(with event: NSEvent) {
    if case .infrastructure = placementTool { lastPainted = nil } else { finishPan(event) }
  }
  func paintInfrastructure(_ point: CGPoint) {
    guard let tool = placementTool else { return }
    let position = placementPosition(at: point, kind: tool.kind)
    guard (0..<Settlement.size).contains(position.x), (0..<Settlement.size).contains(position.y)
    else {
      updatePlacement(at: point)
      return
    }
    guard position != lastPainted else { return }
    var cursor = lastPainted ?? position
    func place(_ grid: GridPosition) {
      commitPlacement(
        at: IsometricLayout.center(
          grid, kind: tool.kind, facing: placementFacing,
          rotation: previous?.layout.viewRotation ?? 0))
    }
    if lastPainted == nil { place(position) }
    while cursor.x != position.x {
      cursor.x += position.x > cursor.x ? 1 : -1
      place(cursor)
    }
    while cursor.y != position.y {
      cursor.y += position.y > cursor.y ? 1 : -1
      place(cursor)
    }
    lastPainted = position
  }
  override func rightMouseDown(with event: NSEvent) { beginPan(event, force: true) }
  override func rightMouseDragged(with event: NSEvent) { continuePan(event) }
  override func rightMouseUp(with event: NSEvent) { finishPan(event) }
  override func otherMouseDown(with event: NSEvent) { beginPan(event, force: true) }
  override func otherMouseDragged(with event: NSEvent) { continuePan(event) }
  override func otherMouseUp(with event: NSEvent) { finishPan(event) }
  override func mouseMoved(with event: NSEvent) { updatePlacement(at: event.location(in: self)) }
  override func scrollWheel(with event: NSEvent) { scrollCamera(event) }
  override func magnify(with event: NSEvent) {
    cameraState.zoom(
      by: 1 / max(0.1, 1 + event.magnification), anchor: event.location(in: self), viewport: size)
    applyCamera()
  }
}
