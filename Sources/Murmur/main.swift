import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    var item: NSStatusItem!
    let popover = NSPopover()
    var hotKey: HotKey?
    var phaseObserver: Any?

    func applicationDidFinishLaunching(_ n: Notification) {
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView(model: model))

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(clicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon()

        // Global hotkey: ⌥Space toggles recording from anywhere, without opening the window.
        hotKey = HotKey { [weak self] in self?.model.toggle() }

        phaseObserver = model.$phase.sink { [weak self] _ in DispatchQueue.main.async { self?.updateIcon() } }
    }

    func updateIcon() {
        let (name, tint): (String, NSColor?) = switch model.phase {
        case .recording: ("record.circle.fill", .systemRed)
        case .transcribing: ("ellipsis.circle", nil)
        default: ("waveform", nil)
        }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Murmur")
        item.button?.image = tint.map { img?.withSymbolConfiguration(.init(paletteColors: [$0])) } ?? img
        item.button?.image?.isTemplate = (tint == nil)
    }

    @objc func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit Murmur", action: #selector(quit), keyEquivalent: "q").target = self
            item.menu = menu; item.button?.performClick(nil); item.menu = nil
            return
        }
        if popover.isShown { popover.performClose(nil) }
        else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc func quit() { model.transcriber.stopServer(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ n: Notification) { model.transcriber.stopServer() }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
