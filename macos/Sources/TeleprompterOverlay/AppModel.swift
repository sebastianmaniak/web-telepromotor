import AppKit
import Combine
import Foundation
import SwiftUI
import TeleprompterCore
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var scripts: [ScriptItem] = []
    @Published var loadedScript: ScriptItem?
    @Published var blocks: [Block] = []
    @Published var overlayVisible = false
    @Published var hudVisible = true
    @Published var permissionNotice: String?
    @Published var alertMessage: String?
    @Published var timerFlashOpacity: Double = 1
    @Published var engine: TeleprompterEngine

    let hudTimeout: TimeInterval = 3
    private var lastInteraction = Date()
    private var hudTicker: Timer?
    private var secondTicker: Timer?
    private var flashTicker: Timer?
    private var overlay: OverlayWindowController?
    private var hotkeys: HotkeyCenter?
    private var link: DisplayLinkDriver?
    private var defaults: UserDefaults
    private var scriptsFolder: URL?
    private var bookmarkData: Data? {
        get { defaults.data(forKey: "tp_scriptsFolderBookmark") }
        set { defaults.set(newValue, forKey: "tp_scriptsFolderBookmark") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let speed = defaults.object(forKey: "tp_speed") as? Int ?? 150
        let font = defaults.object(forKey: "tp_fontSize") as? Int ?? 32
        let timer = defaults.object(forKey: "tp_timer") as? Int ?? 300
        self.engine = TeleprompterEngine(speed: speed, fontSize: font, timerDuration: timer)
        refreshScripts()
        startHudTicker()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.overlay?.moveToMainIfNeeded() }
        }
    }

    func refreshScripts() {
        let bookmark = resolvedBookmarkURL()
        scriptsFolder = ScriptStore.resolveScriptsFolder(
            bookmark: bookmark,
            executableURL: Bundle.main.bundleURL,
            fileManager: .default,
            repoWalkStart: URL(fileURLWithPath: #filePath)
        )
        if let scriptsFolder {
            scripts = ScriptStore.listScripts(in: scriptsFolder)
        } else {
            scripts = []
        }
    }

    func loadScript(_ item: ScriptItem) {
        if !Block.hasContent(item.blocks) {
            alertMessage = "Nothing to read in this file."
            return
        }
        loadedScript = item
        blocks = item.blocks
        engine.restart()
        engine.pause()
        persistLastScript(item.url)
        showOverlay()
    }

    func loadURL(_ url: URL) {
        do {
            let item = try ScriptStore.load(url: url)
            loadScript(item)
        } catch {
            defaults.removeObject(forKey: "tp_lastScriptPath")
            alertMessage = "Could not read that file."
        }
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a markdown script"
        if panel.runModal() == .OK, let url = panel.url {
            loadURL(url)
        }
    }

    func chooseScriptsFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                bookmarkData = data
            }
            refreshScripts()
        }
    }

    func togglePlay() {
        if engine.playing {
            engine.pause()
            hudVisible = true
            overlay?.setClickThrough(false)
            link?.stop()
        } else {
            if !overlayVisible {
                showOverlay()
            }
            engine.play()
            noteInteraction()
            link?.start()
        }
        objectWillChange.send()
    }

    func nudgeScroll(_ delta: Double) {
        engine.nudgeScroll(delta)
        noteInteraction()
        objectWillChange.send()
    }

    func restart() {
        let wasPlaying = engine.playing
        engine.restart()
        if wasPlaying { engine.play() }
        noteInteraction()
        objectWillChange.send()
    }

    func setSpeed(_ wpm: Int) {
        engine.setSpeed(wpm)
        defaults.set(engine.speed, forKey: "tp_speed")
        noteInteraction()
        objectWillChange.send()
    }

    func setFontSize(_ px: Int) {
        engine.setFontSize(px)
        defaults.set(engine.fontSize, forKey: "tp_fontSize")
        noteInteraction()
        objectWillChange.send()
    }

    func adjustTimer(steps: Int) {
        let next = engine.timerDuration + steps * TeleprompterEngine.timerStep
        engine.setTimerDuration(TeleprompterEngine.clampTimer(next))
        defaults.set(engine.timerDuration, forKey: "tp_timer")
        objectWillChange.send()
    }

    func showOverlay() {
        if overlay == nil {
            let controller = OverlayWindowController(rootView: OverlayView(model: self))
            overlay = controller
        }
        overlay?.showWindow(nil)
        overlayVisible = true
        hudVisible = true
        overlay?.setClickThrough(false)
        hotkeys?.stop()
        let hk = HotkeyCenter(model: self)
        hk.start()
        hotkeys = hk
        if link == nil {
            link = DisplayLinkDriver { [weak self] dt in
                guard let self else { return }
                self.engine.tick(elapsed: dt)
                if !self.engine.playing {
                    self.hudVisible = true
                    self.overlay?.setClickThrough(false)
                    self.link?.stop()
                }
                self.objectWillChange.send()
            }
        }
        noteInteraction()
    }

    func hideOverlay() {
        engine.pause()
        link?.stop()
        hotkeys?.stop()
        overlay?.close()
        overlay = nil
        overlayVisible = false
        hudVisible = true
    }

    func revealHUD() {
        guard overlayVisible else { return }
        hudVisible = true
        overlay?.setClickThrough(false)
        noteInteraction()
    }

    func handleEscape() {
        if hudVisible {
            if engine.playing {
                hudVisible = false
                overlay?.setClickThrough(true)
            } else {
                hideOverlay()
            }
        } else {
            hideOverlay()
        }
    }

    func noteInteraction() {
        lastInteraction = Date()
    }

    func reportHotkeyPermissionFailure() {
        if permissionNotice == nil {
            permissionNotice = "Keyboard shortcuts while other apps are focused need Input Monitoring or Accessibility. Overlay still works from this menu."
        }
    }

    private func startHudTicker() {
        hudTicker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickHUD() }
        }
        secondTicker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.engine.playing else { return }
                self.engine.advanceTimer(seconds: 1)
                if self.engine.timerRemaining == 0 { self.startFlash() }
                self.objectWillChange.send()
            }
        }
    }

    private func tickHUD() {
        guard overlayVisible, engine.playing, hudVisible else { return }
        if Date().timeIntervalSince(lastInteraction) >= hudTimeout {
            hudVisible = false
            overlay?.setClickThrough(true)
        }
    }

    private func startFlash() {
        guard flashTicker == nil else { return }
        flashTicker = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.timerFlashOpacity = (self?.timerFlashOpacity ?? 1) == 1 ? 0.2 : 1
            }
        }
    }

    private func resolvedBookmarkURL() -> URL? {
        guard let bookmarkData else { return nil }
        var stale = false
        let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        _ = url?.startAccessingSecurityScopedResource()
        return url
    }

    private func persistLastScript(_ url: URL) {
        defaults.set(url.path, forKey: "tp_lastScriptPath")
    }
}
