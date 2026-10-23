import Foundation
import RazesCore

struct SaveStore {
  static let filename = "settlement-v9.json"
  let url: URL
  private let preserveOriginal: (URL, URL) throws -> Void
  init(
    url: URL,
    preserveOriginal: @escaping (URL, URL) throws -> Void = {
      try FileManager.default.copyItem(at: $0, to: $1)
    }
  ) {
    self.url = url
    self.preserveOriginal = preserveOriginal
  }
  static func applicationStore() throws -> SaveStore {
    let directory = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    return SaveStore(
      url: directory.appendingPathComponent("Razes").appendingPathComponent(filename))
  }
  func load() throws -> GameState? {
    do { return try SaveCodec.decode(Data(contentsOf: url)) } catch let error as CocoaError
      where error.code == .fileReadNoSuchFile
    { return nil }
  }
  func save(_ state: GameState) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      let original = try Data(contentsOf: url)
      _ = try SaveCodec.decode(original)
    }
    try write(state)
  }
  private func write(_ state: GameState) throws {
    let bytes = try SaveCodec.encode(state)
    _ = try SaveCodec.decode(bytes)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try bytes.write(to: url, options: .atomic)
  }
  func startFresh(_ state: GameState) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      let backup = url.deletingLastPathComponent().appendingPathComponent(
        "household-recovery-\(UUID().uuidString).json")
      try preserveOriginal(url, backup)
    }
    try write(state)
  }
}
