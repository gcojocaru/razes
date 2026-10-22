import Foundation
import RazesCore

struct SaveStore {
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
    return SaveStore(url: directory.appendingPathComponent("Razes/household-v1.json"))
  }
  func load() throws -> GameState? {
    do { return try SaveCodec.decode(Data(contentsOf: url)) } catch let error as CocoaError
      where error.code == .fileReadNoSuchFile
    { return nil }
  }
  func save(_ state: GameState) throws {
    let bytes = try SaveCodec.encode(state)
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
    try save(state)
  }
}
