import AVFoundation

/// Records microphone audio into memory only (16 kHz mono Float32). Nothing touches disk.
final class Recorder {
    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private let lock = NSLock()
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

    /// Called on the audio thread with a 0...1 level for the waveform.
    var onLevel: ((Float) -> Void)?

    static func requestPermission(_ done: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: done(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { ok in DispatchQueue.main.async { done(ok) } }
        default: done(false)
        }
    }

    func start() throws {
        samples.removeAll(keepingCapacity: true)
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inFormat, to: target) else {
            throw NSError(domain: "Murmur", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio converter"])
        }
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let ratio = self.target.sampleRate / inFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
            guard let out = AVAudioPCMBuffer(pcmFormat: self.target, frameCapacity: capacity) else { return }
            var fed = false
            converter.convert(to: out, error: nil) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true
                status.pointee = .haveData
                return buffer
            }
            guard let ch = out.floatChannelData?[0] else { return }
            let chunk = Array(UnsafeBufferPointer(start: ch, count: Int(out.frameLength)))
            let rms = sqrt(chunk.reduce(0) { $0 + $1 * $1 } / Float(max(chunk.count, 1)))
            self.lock.lock(); self.samples.append(contentsOf: chunk); self.lock.unlock()
            self.onLevel?(min(1, rms * 8))
        }
        engine.prepare()
        try engine.start()
    }

    /// Stops and returns a WAV (16-bit PCM) held in memory.
    func stop() -> Data {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock(); let s = samples; samples.removeAll(); lock.unlock()
        return Recorder.wav(from: s, sampleRate: 16_000)
    }

    var duration: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        return Double(samples.count) / 16_000
    }

    static func wav(from samples: [Float], sampleRate: Int) -> Data {
        var pcm = Data(capacity: samples.count * 2)
        for f in samples {
            var v = Int16(max(-1, min(1, f)) * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: &v) { pcm.append(contentsOf: $0) }
        }
        var d = Data()
        func u32(_ x: UInt32) { var v = x.littleEndian; withUnsafeBytes(of: &v) { d.append(contentsOf: $0) } }
        func u16(_ x: UInt16) { var v = x.littleEndian; withUnsafeBytes(of: &v) { d.append(contentsOf: $0) } }
        d.append("RIFF".data(using: .ascii)!); u32(UInt32(36 + pcm.count))
        d.append("WAVEfmt ".data(using: .ascii)!); u32(16); u16(1); u16(1)
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(UInt32(pcm.count))
        d.append(pcm)
        return d
    }
}
