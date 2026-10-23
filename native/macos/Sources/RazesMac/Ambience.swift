import AVFoundation

@MainActor final class Ambience {
  private var engine: AVAudioEngine?
  private var wind: AVAudioPlayerNode?
  private var cuePlayer: AVAudioPlayerNode?
  private var cueBuffer: AVAudioPCMBuffer?
  private var enabled = false
  func setEnabled(_ value: Bool) {
    enabled = value
    guard value else {
      engine?.pause()
      return
    }
    do {
      if engine == nil { try prepare() }
      try engine?.start()
    } catch {
      enabled = false
      engine?.stop()
      engine = nil
      wind = nil
      cuePlayer = nil
    }
  }
  private func prepare() throws {
    let engine = AVAudioEngine()
    let wind = AVAudioPlayerNode()
    let cue = AVAudioPlayerNode()
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 176400),
      let sound = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8820)
    else { return }
    buffer.frameLength = buffer.frameCapacity
    sound.frameLength = sound.frameCapacity
    var previous: Float = 0
    for i in 0..<Int(buffer.frameLength) {
      previous = (previous + Float.random(in: -0.02...0.02)) / 1.02
      buffer.floatChannelData![0][i] = previous * 0.15
    }
    for i in 0..<Int(sound.frameLength) {
      let t = Double(i) / 44100
      let envelope = max(0, 1 - t / 0.2)
      sound.floatChannelData![0][i] = Float(
        sin(2 * .pi * (440 * t - 275 * t * t)) * envelope * 0.08)
    }
    engine.attach(wind)
    engine.attach(cue)
    engine.connect(wind, to: engine.mainMixerNode, format: format)
    engine.connect(cue, to: engine.mainMixerNode, format: format)
    try engine.start()
    wind.scheduleBuffer(buffer, at: nil, options: .loops)
    wind.play()
    self.engine = engine
    self.wind = wind
    cuePlayer = cue
    cueBuffer = sound
  }
  func cue() {
    guard enabled, let cuePlayer, let cueBuffer, engine?.isRunning == true else { return }
    cuePlayer.stop()
    cuePlayer.scheduleBuffer(cueBuffer)
    cuePlayer.play()
  }
}
