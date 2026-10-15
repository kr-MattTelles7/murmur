import Foundation

/// Runs a local whisper.cpp server (loopback only) so the model stays warm between dictations.
final class Transcriber {
    static let modelName = "ggml-large-v3-turbo-q5_0.bin"
    static let modelURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(modelName)")!

    static var modelPath: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Murmur/models/\(modelName)")
    }

    static var serverBinary: String? {
        ["/opt/homebrew/bin/whisper-server", "/usr/local/bin/whisper-server"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private var process: Process?
    private var port = 0

    enum Failure: LocalizedError {
        case noBinary, noModel, server(String)
        var errorDescription: String? {
            switch self {
            case .noBinary: return "whisper-cpp isn't installed. Run: brew install whisper-cpp"
            case .noModel: return "Speech model not downloaded yet."
            case .server(let m): return m
            }
        }
    }

    var isModelPresent: Bool { FileManager.default.fileExists(atPath: Transcriber.modelPath.path) }

    func startServer() throws {
        guard process?.isRunning != true else { return }
        guard let bin = Transcriber.serverBinary else { throw Failure.noBinary }
        guard isModelPresent else { throw Failure.noModel }
        port = Int.random(in: 49_152...60_000)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = ["-m", Transcriber.modelPath.path, "--host", "127.0.0.1", "--port", String(port),
                       "-l", "en", "-nt", "-sns", "-t", String(max(4, ProcessInfo.processInfo.activeProcessorCount - 2))]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        process = p
    }

    func stopServer() { process?.terminate(); process = nil }

    /// Waits for the server to accept connections (model load takes a few seconds).
    private func waitUntilReady() async throws {
        for _ in 0..<120 {
            guard process?.isRunning == true else { throw Failure.server("Speech engine stopped unexpectedly.") }
            var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/")!)
            req.timeoutInterval = 1
            if let (_, resp) = try? await URLSession.shared.data(for: req), resp is HTTPURLResponse { return }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        throw Failure.server("Speech engine took too long to start.")
    }

    func transcribe(wav: Data) async throws -> String {
        try startServer()
        try await waitUntilReady()

        let boundary = "murmur-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.wav\"\r\nContent-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wav)
        body.append("\r\n".data(using: .utf8)!)
        field("response_format", "json")
        field("temperature", "0.0")
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/inference")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 120
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = obj["text"] as? String else { throw Failure.server("Unexpected response from speech engine.") }
        return Transcriber.clean(text)
    }

    static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "[BLANK_AUDIO]", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Downloads the model on first launch, with progress.
final class ModelDownloader: NSObject, URLSessionDownloadDelegate {
    var onProgress: ((Double) -> Void)?
    var onDone: ((Error?) -> Void)?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)

    func start() { session.downloadTask(with: Transcriber.modelURL).resume() }

    func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten w: Int64, totalBytesExpectedToWrite t: Int64) {
        if t > 0 { onProgress?(Double(w) / Double(t)) }
    }

    func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo loc: URL) {
        do {
            let dest = Transcriber.modelPath
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: loc, to: dest)
            onDone?(nil)
        } catch { onDone?(error) }
    }

    func urlSession(_ s: URLSession, task: URLSessionTask, didCompleteWithError e: Error?) { if let e { onDone?(e) } }
}
