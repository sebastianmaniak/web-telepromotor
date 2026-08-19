import XCTest
@testable import TeleprompterCore

final class TeleprompterEngineTests: XCTestCase {
    func makeEngine() -> TeleprompterEngine {
        TeleprompterEngine(
            speed: 150,
            fontSize: 32,
            timerDuration: 10,
            viewportWidth: 1000,
            viewportHeight: 800,
            contentHeight: 4000
        )
    }

    func testPlayPauseRestart() {
        let e = makeEngine()
        XCTAssertFalse(e.playing)
        e.play()
        XCTAssertTrue(e.playing)
        e.pause()
        XCTAssertFalse(e.playing)
        e.scrollY = 100
        e.timerRemaining = 3
        e.restart()
        XCTAssertEqual(e.scrollY, 0)
        XCTAssertEqual(e.timerRemaining, 10)
        XCTAssertFalse(e.playing)
    }

    func testRestartKeepsPlayingState() {
        let e = makeEngine()
        e.play()
        e.scrollY = 50
        e.restart()
        XCTAssertTrue(e.playing)
        XCTAssertEqual(e.scrollY, 0)
    }

    func testHigherWpmMovesMorePixels() {
        let slow = makeEngine()
        slow.setSpeed(100)
        slow.play()
        slow.tick(elapsed: 1)
        let slowY = slow.scrollY

        let fast = makeEngine()
        fast.setSpeed(200)
        fast.play()
        fast.tick(elapsed: 1)
        XCTAssertGreaterThan(fast.scrollY, slowY)
        XCTAssertEqual(fast.scrollY / slowY, 2, accuracy: 0.01)
    }

    func testTickDoesNothingWhenPaused() {
        let e = makeEngine()
        e.tick(elapsed: 1)
        XCTAssertEqual(e.scrollY, 0)
    }

    func testClampAtEndAutoPauses() {
        let e = makeEngine()
        e.play()
        e.tick(elapsed: 10_000)
        let maxScroll = e.contentHeight - e.viewportHeight * 0.33
        XCTAssertEqual(e.scrollY, maxScroll, accuracy: 0.01)
        XCTAssertFalse(e.playing)
    }

    func testTimerCountsDownOnlyWhilePlaying() {
        let e = makeEngine()
        e.advanceTimer(seconds: 2)
        XCTAssertEqual(e.timerRemaining, 10)
        e.play()
        e.advanceTimer(seconds: 3)
        XCTAssertEqual(e.timerRemaining, 7)
        e.pause()
        e.advanceTimer(seconds: 3)
        XCTAssertEqual(e.timerRemaining, 7)
        e.play()
        e.advanceTimer(seconds: 100)
        XCTAssertEqual(e.timerRemaining, 0)
    }

    func testSpeedAndFontClamps() {
        let e = makeEngine()
        e.setSpeed(10)
        XCTAssertEqual(e.speed, 50)
        e.setSpeed(999)
        XCTAssertEqual(e.speed, 400)
        e.setFontSize(2)
        XCTAssertEqual(e.fontSize, 20)
        e.setFontSize(200)
        XCTAssertEqual(e.fontSize, 64)
    }

    func testProgressAndTimerDisplay() {
        let e = makeEngine()
        XCTAssertEqual(e.progress, 0)
        XCTAssertEqual(e.timerDisplay, "0:10")
        e.scrollY = e.maxScroll
        XCTAssertEqual(e.progress, 1, accuracy: 0.001)
    }
}
