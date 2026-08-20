import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyCenter {
    private weak var model: AppModel?
    private var localKey: Any?
    private var globalKey: Any?
    private var globalMouse: Any?

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        stop()
        localKey = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handle(event) == true { return nil }
            return event
        }
        globalKey = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handle(event)
        }
        globalMouse = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.model?.revealHUD()
        }
        if globalKey == nil {
            model?.reportHotkeyPermissionFailure()
        }
    }

    func stop() {
        if let localKey { NSEvent.removeMonitor(localKey) }
        if let globalKey { NSEvent.removeMonitor(globalKey) }
        if let globalMouse { NSEvent.removeMonitor(globalMouse) }
        localKey = nil
        globalKey = nil
        globalMouse = nil
    }

    @discardableResult
    private func handle(_ event: NSEvent) -> Bool {
        guard let model, model.overlayVisible else { return false }
        if event.modifierFlags.contains(.command) { return false }

        switch event.keyCode {
        case UInt16(kVK_Space):
            model.revealHUD()
            model.togglePlay()
            return true
        case UInt16(kVK_UpArrow):
            model.setSpeed(model.engine.speed + 10)
            model.revealHUD()
            return true
        case UInt16(kVK_DownArrow):
            model.setSpeed(model.engine.speed - 10)
            model.revealHUD()
            return true
        case UInt16(kVK_ANSI_Equal), UInt16(kVK_ANSI_KeypadPlus):
            model.setFontSize(model.engine.fontSize + 2)
            model.revealHUD()
            return true
        case UInt16(kVK_ANSI_Minus), UInt16(kVK_ANSI_KeypadMinus):
            model.setFontSize(model.engine.fontSize - 2)
            model.revealHUD()
            return true
        case UInt16(kVK_ANSI_R):
            model.restart()
            model.revealHUD()
            return true
        case UInt16(kVK_Escape):
            model.handleEscape()
            return true
        default:
            return false
        }
    }
}
