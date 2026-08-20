import AppKit
import SwiftUI

final class OverlayWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayWindowController: NSWindowController {
    private static let frameDefaultsKey = "tp_overlayFrame"
    private var hosting: NSHostingController<OverlayView>?

    convenience init(rootView: OverlayView) {
        let screen = OverlayWindowController.screenUnderMouse() ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = OverlayWindowController.initialFrame(on: screen)
        let panel = OverlayWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.setFrame(frame, display: false)
        panel.minSize = NSSize(width: 360, height: 160)
        panel.isOpaque = false
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.title = "Teleprompter"
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = false
        panel.isFloatingPanel = true
        self.init(window: panel)
        let host = NSHostingController(rootView: rootView)
        host.view.frame = panel.contentView?.bounds ?? frame
        host.view.autoresizingMask = [.width, .height]
        panel.contentViewController = host
        hosting = host
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { [weak panel] _ in
            let frame = panel?.frame
            Task { @MainActor in OverlayWindowController.saveFrame(frame) }
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak panel] _ in
            let frame = panel?.frame
            Task { @MainActor in OverlayWindowController.saveFrame(frame) }
        }
    }

    func setClickThrough(_ enabled: Bool) {
        window?.ignoresMouseEvents = enabled
    }

    func pin(to screen: NSScreen) {
        var frame = window?.frame ?? OverlayWindowController.defaultFrame(on: screen)
        let vis = screen.visibleFrame
        if !vis.intersects(frame) {
            frame.origin.x = vis.midX - frame.width / 2
            frame.origin.y = vis.maxY - frame.height - 24
            window?.setFrame(frame, display: true)
        }
    }

    func moveToMainIfNeeded() {
        let current = window?.screen
        if current == nil || !(NSScreen.screens.contains { $0 === current }) {
            if let main = NSScreen.main {
                pin(to: main)
            }
        }
    }

    static func screenUnderMouse() -> NSScreen? {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) }
    }

    private static func initialFrame(on screen: NSScreen) -> NSRect {
        if let saved = savedFrame(), screen.visibleFrame.intersects(saved) {
            return saved
        }
        return defaultFrame(on: screen)
    }

    private static func defaultFrame(on screen: NSScreen) -> NSRect {
        let vis = screen.visibleFrame
        let width = min(720, vis.width * 0.5)
        let height = min(260, vis.height * 0.28)
        return NSRect(
            x: vis.midX - width / 2,
            y: vis.maxY - height - 28,
            width: width,
            height: height
        )
    }

    private static func savedFrame() -> NSRect? {
        let s = UserDefaults.standard.string(forKey: frameDefaultsKey) ?? ""
        let parts = s.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else { return nil }
        return NSRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    static func saveFrame(_ frame: NSRect?) {
        guard let frame else { return }
        let s = "\(frame.origin.x),\(frame.origin.y),\(frame.size.width),\(frame.size.height)"
        UserDefaults.standard.set(s, forKey: frameDefaultsKey)
    }
}
