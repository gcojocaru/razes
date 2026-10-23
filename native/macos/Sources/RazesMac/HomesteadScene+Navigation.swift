import AppKit
import RazesCore
import SpriteKit

extension HomesteadScene {
  func projected(_ point: CGPoint) -> CGPoint {
    let grid = IsometricLayout.grid(at: point)
    return IsometricLayout.point(
      column: grid.x, row: grid.y, rotation: previous?.layout.viewRotation ?? 0)
  }
  func unprojected(_ point: CGPoint) -> CGPoint {
    let grid = IsometricLayout.grid(at: point, rotation: previous?.layout.viewRotation ?? 0)
    return IsometricLayout.point(column: grid.x, row: grid.y)
  }

  func applyCamera() {
    onCameraChange?(Int((100 / cameraState.scale).rounded()))
    navigationCamera.position = cameraState.center
    navigationCamera.setScale(cameraState.scale)
    if let weather = childNode(withName: "weather") {
      weather.position = CGPoint(
        x: cameraState.center.x - size.width * cameraState.scale / 2,
        y: cameraState.center.y - size.height * cameraState.scale / 2)
      weather.setScale(cameraState.scale)
    }
  }
  func panCamera(x: CGFloat, y: CGFloat) {
    cameraState.pan(by: CGPoint(x: x * cameraState.scale, y: y * cameraState.scale), viewport: size)
    applyCamera()
  }
  func zoomCamera(_ factor: CGFloat) {
    cameraState.zoom(by: factor, anchor: cameraState.center, viewport: size)
    applyCamera()
  }
  func resetCamera() {
    cameraState.reset(viewport: size)
    applyCamera()
  }
  func setPlacement(_ tool: PlacementTool?) {
    placementTool = tool
    updatePlacement(at: lastPointer)
  }
  func placementPosition(at point: CGPoint, kind: StructureKind) -> GridPosition {
    let grid = IsometricLayout.grid(at: point, rotation: previous?.layout.viewRotation ?? 0)
    let footprint = Settlement.footprint(kind, facing: placementFacing)
    return GridPosition(
      x: Int((grid.x - CGFloat(footprint.width - 1) / 2).rounded()),
      y: Int((grid.y - CGFloat(footprint.height - 1) / 2).rounded()))
  }
  func updatePlacement(at point: CGPoint) {
    lastPointer = point
    placementOverlay.removeAllChildren()
    guard let tool = placementTool, let state = previous else { return }
    let position = placementPosition(at: point, kind: tool.kind)
    let footprint = Settlement.footprint(tool.kind, facing: placementFacing)
    let problem = Settlement.problem(
      tool.kind, at: position, layout: state.layout, facing: placementFacing)
    let path = CGMutablePath()
    path.addLines(between: [
      projected(
        IsometricLayout.point(column: CGFloat(position.x) - 0.5, row: CGFloat(position.y) - 0.5)),
      projected(
        IsometricLayout.point(
          column: CGFloat(position.x + footprint.width) - 0.5, row: CGFloat(position.y) - 0.5)),
      projected(
        IsometricLayout.point(
          column: CGFloat(position.x + footprint.width) - 0.5,
          row: CGFloat(position.y + footprint.height) - 0.5)),
      projected(
        IsometricLayout.point(
          column: CGFloat(position.x) - 0.5, row: CGFloat(position.y + footprint.height) - 0.5)),
    ])
    path.closeSubpath()
    let outline = SKShapeNode(path: path)
    outline.strokeColor = problem == nil ? .systemGreen : .systemRed
    outline.fillColor = outline.strokeColor.withAlphaComponent(0.2)
    outline.lineWidth = 2 * cameraState.scale
    outline.zPosition = 2
    placementOverlay.addChild(outline)
    let center = IsometricLayout.center(
      position, kind: tool.kind, facing: placementFacing, rotation: state.layout.viewRotation)
    if case .building(let id, _, let instant) = tool {
      let ghost = SKSpriteNode(
        texture: buildingTexture(
          id, level: state.buildings.first { $0.id == id }?.level ?? 1, planned: !instant,
          winter: state.displaySeason == 3,
          facing: (placementFacing + state.layout.viewRotation) % 4))
      if (placementFacing + state.layout.viewRotation) % 2 == 1, let texture = ghost.texture {
        ghost.texture = mirroredTexture(texture)
      }
      ghost.anchorPoint = CGPoint(x: 0.5, y: 0)
      let width = Self.plotSizes[id]!.width
      ghost.size = CGSize(
        width: width,
        height: width * (ghost.texture?.size().height ?? 1)
          / max(1, ghost.texture?.size().width ?? 1))
      ghost.position = center
      ghost.alpha = 0.55
      placementOverlay.addChild(ghost)
    }
    if tool.kind == .infrastructure(.fence) {
      let (a, b) = fenceEndpoints(
        .init(position: position, facing: placementFacing), rotation: state.layout.viewRotation)
      let edge = CGMutablePath()
      edge.move(to: CGPoint(x: a.x, y: a.y + 27))
      edge.addLine(to: CGPoint(x: b.x, y: b.y + 27))
      for p in [a, b] {
        edge.move(to: p)
        edge.addLine(to: CGPoint(x: p.x, y: p.y + 36))
      }
      let fence = SKShapeNode(path: edge)
      fence.strokeColor = outline.strokeColor
      fence.lineWidth = 5
      fence.zPosition = 2
      placementOverlay.addChild(fence)
    }
    let label = SKLabelNode(fontNamed: "DMSans9pt-Regular")
    label.text =
      problem ?? "Click to place \(tool.title.lowercased()) · \(position.x), \(position.y)"
    label.fontSize = 14 * cameraState.scale
    label.fontColor = .white
    label.zPosition = 3
    label.position = CGPoint(
      x: center.x,
      y: center.y - CGFloat(footprint.width + footprint.height) * 16.5 - 24 * cameraState.scale)
    placementOverlay.addChild(label)
  }
  func commitPlacement(at point: CGPoint) {
    guard let tool = placementTool, let state = previous else { return }
    let position = placementPosition(at: point, kind: tool.kind)
    updatePlacement(at: point)
    guard
      Settlement.problem(tool.kind, at: position, layout: state.layout, facing: placementFacing)
        == nil
    else { return }
    onPlacement?(tool, position)
  }
  func beginPan(_ event: NSEvent, force: Bool = false) {
    dragStart = event.locationInWindow
    dragLast = dragStart
    dragged = force
  }
  func continuePan(_ event: NSEvent) {
    guard let start = dragStart, let last = dragLast else { return }
    let point = event.locationInWindow
    if hypot(point.x - start.x, point.y - start.y) > 4 { dragged = true }
    if dragged {
      cameraState.pan(
        by: CGPoint(
          x: (last.x - point.x) * cameraState.scale, y: (last.y - point.y) * cameraState.scale),
        viewport: size)
      applyCamera()
      updatePlacement(at: event.location(in: self))
    }
    dragLast = point
  }
  func finishPan(_ event: NSEvent) {
    defer {
      dragStart = nil
      dragLast = nil
      dragged = false
    }
    guard !dragged else { return }
    let point = event.location(in: self)
    if placementTool != nil {
      commitPlacement(at: point)
    } else if let target = selection(at: point) {
      onSelection?(target)
    }
  }
  func scrollCamera(_ event: NSEvent) {
    if !event.modifierFlags.intersection([.option, .command]).isEmpty {
      cameraState.zoom(
        by: exp(-event.scrollingDeltaY * 0.015), anchor: event.location(in: self), viewport: size)
    } else {
      let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 12
      cameraState.pan(
        by: CGPoint(
          x: -event.scrollingDeltaX * multiplier * cameraState.scale,
          y: event.scrollingDeltaY * multiplier * cameraState.scale), viewport: size)
    }
    applyCamera()
    updatePlacement(at: event.location(in: self))
  }
}
