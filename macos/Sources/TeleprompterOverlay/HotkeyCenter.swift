import AppKit

@MainActor
final class HotkeyCenter {
    private weak var model: AppModel?
    init(model: AppModel) { self.model = model }
    func start() {}
    func stop() {}
}
