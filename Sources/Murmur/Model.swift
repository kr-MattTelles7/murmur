import AppKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable { case needsModel, downloading(Double), idle, recording, transcribing, error(String) }

    @Published var phase: Phase = .idle
    @Published var text = ""
    @Published var levels: [Float] = Array(repeating: 0, count: 28)
    @Published var copied = false
    @Published var autoCopy = UserDefaults.standard.object(forKey: "autoCopy") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoCopy, forKey: "autoCopy") }
    }

    let recorder = Recorder()
    let transcriber = Transcriber()
    private let downloader = ModelDownloader()
    var onPhaseChange: ((Phase) -> Void)?

    init() {
        recorder.onLevel = { [weak self] l in
            DispatchQueue.main.async {
                guard let self else { return }
                self.levels.removeFirst(); self.levels.append(l)
            }
        }
        if !transcriber.isModelPresent { phase = .needsModel }
        else { warmUp() }
    }

    func warmUp() { try? transcriber.startServer() }

    func downloadModel() {
        phase = .downloading(0)
        downloader.onProgress = { [weak self] p in Task { @MainActor in self?.phase = .downloading(p) } }
        downloader.onDone = { [weak self] err in
            Task { @MainActor in
                guard let self else { return }
                if let err { self.phase = .error(err.localizedDescription) }
                else { self.phase = .idle; self.warmUp() }
            }
        }
        downloader.start()
    }

    func toggle() {
        switch phase {
        case .recording: finish()
        case .idle, .error: begin()
        default: break
        }
    }

    private func begin() {
        Recorder.requestPermission { [weak self] ok in
            guard let self else { return }
            guard ok else { self.phase = .error("Microphone access is off. Enable it in System Settings → Privacy & Security → Microphone."); return }
            do {
                self.copied = false
                try self.recorder.start()
                self.levels = Array(repeating: 0, count: self.levels.count)
                self.phase = .recording
            } catch { self.phase = .error(error.localizedDescription) }
        }
    }

    private func finish() {
        let tooShort = recorder.duration < 0.4
        let wav = recorder.stop()
        if tooShort { phase = .idle; return }
        phase = .transcribing
        Task {
            do {
                let result = try await transcriber.transcribe(wav: wav)
                if result.isEmpty { phase = .error("Didn't catch anything. Try again.") ; return }
                text = text.isEmpty ? result : text + " " + result
                if autoCopy { copy() }
                phase = .idle
            } catch { phase = .error(error.localizedDescription) }
        }
    }

    func copy() {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        Task { try? await Task.sleep(nanoseconds: 1_600_000_000); copied = false }
    }

    func clear() { text = ""; copied = false; if case .error = phase { phase = .idle } }
}
