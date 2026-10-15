import SwiftUI

struct Waveform: View {
    let levels: [Float]
    let active: Bool
    var body: some View {
        HStack(spacing: 3) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(active ? Color.red.opacity(0.85) : Color.secondary.opacity(0.35))
                    .frame(width: 3, height: 4 + CGFloat(active ? levels[i] : 0) * 28)
            }
        }
        .frame(height: 36)
        .animation(.easeOut(duration: 0.08), value: levels)
    }
}

struct MicButton: View {
    let phase: AppModel.Phase
    let action: () -> Void

    var recording: Bool { phase == .recording }
    var busy: Bool { phase == .transcribing }

    var body: some View {
        Button(action: action) {
            ZStack {
                if recording {
                    TimelineView(.animation) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.1) / 1.1
                        Circle().stroke(Color.red.opacity(0.35), lineWidth: 2)
                            .frame(width: 44, height: 44)
                            .scaleEffect(1 + 0.35 * t).opacity(1 - t)
                    }
                }
                Circle().fill(recording ? Color.red : Color.accentColor)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                if busy { ProgressView().controlSize(.small).tint(.white) }
                else { Image(systemName: recording ? "stop.fill" : "mic.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white) }
            }
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .help(recording ? "Stop (⌥Space)" : "Record (⌥Space)")
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel

    var status: String {
        switch model.phase {
        case .needsModel: return "One-time setup needed"
        case .downloading(let p): return "Downloading speech model… \(Int(p * 100))%"
        case .idle: return model.text.isEmpty ? "Press ⌥Space anywhere to dictate" : "Ready"
        case .recording: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .error(let m): return m
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            if case .needsModel = model.phase {
                setup(title: "Download speech model", detail: "About 570 MB, stored locally. Audio never leaves your Mac.", buttonTitle: "Download", action: model.downloadModel)
            } else if case .downloading(let p) = model.phase {
                VStack(spacing: 10) {
                    ProgressView(value: p).progressViewStyle(.linear)
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }.frame(maxHeight: .infinity)
            } else {
                HStack(spacing: 14) {
                    MicButton(phase: model.phase, action: model.toggle)
                    Waveform(levels: model.levels, active: model.phase == .recording).frame(maxWidth: .infinity)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor))
                    if model.text.isEmpty {
                        // No editor while empty: nothing to type into, no stray cursor.
                        VStack(spacing: 6) {
                            Image(systemName: "text.bubble").font(.system(size: 20)).foregroundStyle(.quaternary)
                            Text("Your words appear here").font(.system(size: 12)).foregroundStyle(.tertiary)
                        }
                    } else {
                        TextEditor(text: $model.text)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .disabled(model.phase == .recording || model.phase == .transcribing)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))

                HStack {
                    if case .error = model.phase {
                        Label(status, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).lineLimit(2)
                    } else {
                        Text(status)
                    }
                    Spacer()
                    Toggle("Auto-copy", isOn: $model.autoCopy).toggleStyle(.checkbox).controlSize(.small)
                }
                .font(.caption).foregroundStyle(.secondary)

                HStack {
                    Button("Clear") { model.clear() }.disabled(model.text.isEmpty)
                    Spacer()
                    Button { model.copy() } label: {
                        Label(model.copied ? "Copied" : "Copy", systemImage: model.copied ? "checkmark" : "doc.on.doc")
                            .frame(minWidth: 70)
                    }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .buttonStyle(.borderedProminent)
                    .disabled(model.text.isEmpty)
                }
            }
        }
        .padding(14)
        .frame(width: 340, height: 300)
    }

    func setup(title: String, detail: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill").font(.system(size: 40)).foregroundStyle(Color.accentColor)
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(buttonTitle, action: action).buttonStyle(.borderedProminent).controlSize(.large)
        }.frame(maxHeight: .infinity)
    }
}
