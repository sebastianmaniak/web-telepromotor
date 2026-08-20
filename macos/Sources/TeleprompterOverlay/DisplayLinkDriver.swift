import AppKit
import Foundation

/// Drives scroll on the main run loop. NSScreen/CADisplayLink does not reliably
/// fire for a floating NSPanel, so a 60fps Timer is the source of ticks.
final class DisplayLinkDriver: NSObject {
    private var timer: Timer?
    private let onTick: (TimeInterval) -> Void

    init(onTick: @escaping (TimeInterval) -> Void) {
        self.onTick = onTick
        super.init()
    }

    func start() {
        stop()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.onTick(1.0 / 60.0)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}
