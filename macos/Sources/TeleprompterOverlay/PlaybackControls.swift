import SwiftUI
import TeleprompterCore

struct PlaybackControls: View {
    @ObservedObject var model: AppModel
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            Button("Play") { model.play() }
                .disabled(model.engine.playing || (model.scripts.isEmpty && model.loadedScript == nil))
            Button("Pause") { model.pause() }
                .disabled(!model.engine.playing)
            if !compact {
                Button("Restart") { model.restart() }
                    .disabled(model.loadedScript == nil)
            }
            Spacer(minLength: compact ? 4 : 8)
            Button("Slower") { model.slower() }
            Text("Speed \(model.engine.speed)")
                .monospacedDigit()
                .frame(minWidth: compact ? 72 : 90)
            Button("Faster") { model.faster() }
        }
        .controlSize(compact ? .regular : .large)
    }
}
