import Foundation

final class DisplayLinkDriver {
    init(onTick: @escaping (TimeInterval) -> Void) {}
    func start() {}
    func stop() {}
}
