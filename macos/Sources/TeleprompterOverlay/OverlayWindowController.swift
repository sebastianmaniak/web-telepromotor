import AppKit
import SwiftUI

final class OverlayWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayWindowController: NSWindowController {
    convenience init(rootView: some View) {
        let screen = OverlayWindowController.screenUnderMouse() ?? NSScreen.main ?? NSScreen.screens[0]
        let panel = OverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        let host = NSHostingView(rootView: rootView)
        host.frame = screen.frame
        panel.contentView = host
        self.init(window: panel)
        pin(to: screen)
    }

    func setClickThrough(_ enabled: Bool) {
        window?.ignoresMouseEvents = enabled
    }

    func pin(to screen: NSScreen) {
        window?.setFrame(screen.frame, display: true)
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
}
