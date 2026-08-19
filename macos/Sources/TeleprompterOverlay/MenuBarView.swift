import AppKit
import SwiftUI
import TeleprompterCore

struct MenuBarView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if let notice = model.permissionNotice {
            Text(notice)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 280)
        }
        if let alert = model.alertMessage {
            Text(alert)
            Button("OK") { model.alertMessage = nil }
        }
        if model.scripts.isEmpty {
            Text("No scripts found")
        } else {
            ForEach(model.scripts) { item in
                Button("\(item.displayName) · \(item.wordCount) words") {
                    model.loadScript(item)
                }
            }
        }
        Divider()
        Button("Open file…") { model.openFile() }
        Button("Choose scripts folder…") { model.chooseScriptsFolder() }
        Divider()
        if model.loadedScript != nil {
            if !model.overlayVisible {
                Button("Show overlay") { model.showOverlay() }
            }
            Button(model.engine.playing ? "Pause" : "Start") { model.togglePlay() }
        }
        Menu("Timer \(model.engine.timerDisplay)") {
            Button("+30s") { model.adjustTimer(steps: 1) }
            Button("−30s") { model.adjustTimer(steps: -1) }
        }
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}
