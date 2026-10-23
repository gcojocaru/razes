import CoreGraphics

struct CameraState: Equatable {
  static let bounds = CGRect(x: -456, y: -363, width: 2112, height: 1056)
  var center = CGPoint(x: 600, y: 273)
  var scale: CGFloat = 0.9
  mutating func pan(by offset: CGPoint, viewport: CGSize) {
    center.x += offset.x
    center.y += offset.y
    clamp(viewport)
  }
  mutating func zoom(by factor: CGFloat, anchor: CGPoint, viewport: CGSize) {
    guard factor.isFinite, factor > 0 else { return }
    let next = min(2.4, max(0.55, scale * factor))
    let ratio = next / scale
    center = CGPoint(
      x: anchor.x - (anchor.x - center.x) * ratio, y: anchor.y - (anchor.y - center.y) * ratio)
    scale = next
    clamp(viewport)
  }
  mutating func reset(viewport: CGSize) {
    self = Self()
    clamp(viewport)
  }
  private mutating func clamp(_ viewport: CGSize) {
    let halfWidth = viewport.width * scale / 2
    let halfHeight = viewport.height * scale / 2
    center.x =
      halfWidth * 2 >= Self.bounds.width
      ? Self.bounds.midX
      : min(Self.bounds.maxX - halfWidth, max(Self.bounds.minX + halfWidth, center.x))
    center.y =
      halfHeight * 2 >= Self.bounds.height
      ? Self.bounds.midY
      : min(Self.bounds.maxY - halfHeight, max(Self.bounds.minY + halfHeight, center.y))
  }
}
