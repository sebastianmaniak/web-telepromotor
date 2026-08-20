import Foundation

public final class TeleprompterEngine {
    public static let minSpeed = 50
    public static let maxSpeed = 400
    public static let minFontSize = 20
    public static let maxFontSize = 64
    public static let minTimer = 30
    public static let maxTimer = 1800
    public static let timerStep = 30

    public private(set) var speed: Int
    public private(set) var fontSize: Int
    public private(set) var timerDuration: Int
    public var viewportWidth: Double
    public var viewportHeight: Double
    public var contentHeight: Double
    public var scrollY: Double = 0
    public private(set) var playing = false
    public var timerRemaining: Int

    public init(
        speed: Int = 150,
        fontSize: Int = 32,
        timerDuration: Int = 300,
        viewportWidth: Double = 1440,
        viewportHeight: Double = 900,
        contentHeight: Double = 0
    ) {
        self.speed = Self.clampSpeed(speed)
        self.fontSize = Self.clampFont(fontSize)
        self.timerDuration = timerDuration
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.contentHeight = contentHeight
        self.timerRemaining = timerDuration
    }

    public var maxScroll: Double {
        max(0, contentHeight - viewportHeight * 0.33)
    }

    public var progress: Double {
        let maxS = maxScroll
        if maxS <= 0 { return 1 }
        return min(1, max(0, scrollY / maxS))
    }

    public var timerDisplay: String {
        let mins = timerRemaining / 60
        let secs = timerRemaining % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }

    public var pixelsPerSecond: Double {
        let avgWordLength = 5.0
        let lineHeight = Double(fontSize) * 1.7
        let charsPerLine = floor(viewportWidth / (Double(fontSize) * 0.5))
        let wordsPerLine = max(1, charsPerLine / avgWordLength)
        let linesPerSecond = (Double(speed) / 60.0) / wordsPerLine
        return linesPerSecond * lineHeight
    }

    public func play() { playing = true }
    public func pause() { playing = false }

    public func restart() {
        scrollY = 0
        timerRemaining = timerDuration
    }

    public func setSpeed(_ wpm: Int) { speed = Self.clampSpeed(wpm) }
    public func setFontSize(_ px: Int) { fontSize = Self.clampFont(px) }

    public func setTimerDuration(_ seconds: Int) {
        timerDuration = Self.clampTimer(seconds)
        timerRemaining = timerDuration
    }

    public func tick(elapsed: TimeInterval) {
        guard playing else { return }
        // Layout has not measured the text yet — do not treat that as "finished".
        if maxScroll <= 0 { return }
        scrollY += pixelsPerSecond * elapsed
        if scrollY >= maxScroll {
            scrollY = maxScroll
            pause()
        }
    }

    public func advanceTimer(seconds: Int) {
        guard playing else { return }
        timerRemaining = max(0, timerRemaining - seconds)
    }

    public func nudgeScroll(_ delta: Double) {
        scrollY = min(maxScroll, max(0, scrollY + delta))
    }

    public static func clampSpeed(_ v: Int) -> Int { min(maxSpeed, max(minSpeed, v)) }
    public static func clampFont(_ v: Int) -> Int { min(maxFontSize, max(minFontSize, v)) }
    public static func clampTimer(_ v: Int) -> Int { min(maxTimer, max(minTimer, v)) }
}
