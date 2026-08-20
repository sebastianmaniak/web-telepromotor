import AppKit
import SwiftUI
import TeleprompterCore

struct ScriptPickerView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Teleprompter")
                .font(.title2.weight(.semibold))
            Text("Pick a script, then Start. A small glass window appears — drag it and resize from the corners.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let notice = model.permissionNotice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let alert = model.alertMessage {
                HStack {
                    Text(alert)
                    Button("OK") { model.alertMessage = nil }
                }
            }

            GroupBox("Scripts") {
                if model.scripts.isEmpty {
                    Text("No scripts found")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    List(model.scripts, selection: selection) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                            Text("\(item.wordCount) words")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(item.id)
                    }
                    .listStyle(.inset)
                    .frame(minHeight: 180)
                }
            }

            HStack {
                Button("Open file…") { model.openFile() }
                Button("Choose folder…") { model.chooseScriptsFolder() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }

            HStack {
                Menu("Timer \(model.engine.timerDisplay)") {
                    Button("+30s") { model.adjustTimer(steps: 1) }
                    Button("−30s") { model.adjustTimer(steps: -1) }
                }
                Spacer()
                if model.loadedScript != nil, !model.overlayVisible {
                    Button("Show overlay") { model.showOverlay() }
                }
                Button(model.engine.playing ? "Pause" : "Start") {
                    startSelected()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.scripts.isEmpty && model.loadedScript == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 420)
    }

    private var selection: Binding<String?> {
        Binding(
            get: { model.loadedScript?.id },
            set: { id in
                guard let id, let item = model.scripts.first(where: { $0.id == id }) else { return }
                model.loadScript(item)
            }
        )
    }

    private func startSelected() {
        if model.loadedScript == nil, let first = model.scripts.first {
            model.loadScript(first)
        }
        if model.loadedScript != nil {
            model.togglePlay()
        }
    }
}
