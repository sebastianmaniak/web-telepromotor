import SwiftUI
import TeleprompterCore

struct ControlHUD: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 16) {
            Button(model.engine.playing ? "Pause" : "Play") { model.togglePlay() }
            Button("Restart") { model.restart() }
            VStack(alignment: .leading, spacing: 2) {
                Text("SPEED \(model.engine.speed)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(model.engine.speed) },
                        set: { model.setSpeed(Int($0)) }
                    ),
                    in: Double(TeleprompterEngine.minSpeed)...Double(TeleprompterEngine.maxSpeed),
                    step: 10
                )
                .frame(width: 90)
            }
            HStack(spacing: 6) {
                Button("A−") { model.setFontSize(model.engine.fontSize - 2) }
                Text("\(model.engine.fontSize)")
                    .monospacedDigit()
                Button("A+") { model.setFontSize(model.engine.fontSize + 2) }
            }
            Text("\(Int((model.engine.progress * 100).rounded()))%")
                .monospacedDigit()
            Text(model.engine.timerDisplay)
                .monospacedDigit()
                .foregroundStyle(model.engine.timerRemaining == 0 ? Color.red : Color.primary)
                .opacity(model.engine.timerRemaining == 0 ? model.timerFlashOpacity : 1)
            Text(model.loadedScript?.displayName ?? "")
                .lineLimit(1)
                .frame(maxWidth: 90)
            Button("Close") { model.hideOverlay() }
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 8)
    }
}
