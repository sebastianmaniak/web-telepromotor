import AppKit
import Foundation
import QuartzCore

final class DisplayLinkDriver: NSObject {
    private var link: CADisplayLink?
    private var timer: Timer?
    private var last: CFTimeInterval?
    private let onTick: (TimeInterval) -> Void

    init(onTick: @escaping (TimeInterval) -> Void) {
        self.onTick = onTick
        super.init()
    }

    func start() {
        stop()
        last = nil
        if let screen = NSScreen.main {
            let link = screen.displayLink(target: self, selector: #selector(stepLink(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
            return
        }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.onTick(1.0 / 60.0)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        link?.invalidate()
        link = nil
        timer?.invalidate()
        timer = nil
        last = nil
    }

    @objc private func stepLink(_ link: CADisplayLink) {
        let now = link.timestamp
        if let last {
            onTick(now - last)
        }
        last = now
    }

    deinit {
        link?.invalidate()
        timer?.invalidate()
    }
}
