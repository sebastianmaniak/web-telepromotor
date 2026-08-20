import SwiftUI
import TeleprompterCore

struct ControlHUD: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            PlaybackControls(model: model, compact: true)
            Button("Restart") { model.restart() }
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
            Button("Close") { model.hideOverlay() }
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 8)
    }
}
