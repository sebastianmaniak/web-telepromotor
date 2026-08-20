import SwiftUI
import TeleprompterCore

struct OverlayView: View {
    @ObservedObject var model: AppModel
    @State private var lastDragHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let wrapWidth = max(80, geo.size.width - 40)
            ZStack(alignment: .top) {
                Color.clear
                textStack(width: wrapWidth, viewportHeight: geo.size.height)
                    .frame(width: wrapWidth, alignment: .top)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: -model.scrollY)
                    .gesture(drag)
                guideLine
                if model.hudVisible {
                    VStack {
                        Spacer()
                        ControlHUD(model: model)
                            .padding(.bottom, 8)
                    }
                }
            }
            .clipped()
            .background(Color.clear)
            .onAppear {
                model.engine.viewportWidth = wrapWidth
                model.engine.viewportHeight = geo.size.height
            }
            .onChange(of: geo.size) { _, size in
                model.engine.viewportWidth = max(80, size.width - 40)
                model.engine.viewportHeight = size.height
            }
        }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                guard model.hudVisible else { return }
                let delta = value.translation.height - lastDragHeight
                lastDragHeight = value.translation.height
                model.nudgeScroll(-delta)
            }
            .onEnded { _ in
                lastDragHeight = 0
            }
    }

    private func textStack(width: CGFloat, viewportHeight: CGFloat) -> some View {
        VStack(alignment: .center, spacing: 28) {
            Color.clear.frame(height: viewportHeight * 0.33)
            ForEach(Array(model.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block, width: width)
            }
            Color.clear.frame(height: viewportHeight * 0.5)
        }
        .frame(width: width)
        .background(
            GeometryReader { g in
                Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
            }
        )
        .onPreferenceChange(ContentHeightKey.self) { height in
            if height > 0 {
                model.engine.contentHeight = height
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: Block, width: CGFloat) -> some View {
        switch block {
        case .segment(let title):
            wrappedText(title, width: width)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))
                .shadow(color: .black.opacity(0.9), radius: 3)
        case .say(let text):
            wrappedText(text, width: width)
                .font(.system(size: CGFloat(model.engine.fontSize), weight: .medium))
                .foregroundStyle(Color.white)
                .lineSpacing(CGFloat(model.engine.fontSize) * 0.7)
                .shadow(color: .black.opacity(0.95), radius: 4)
        case .draw(let text):
            wrappedText(text, width: width)
                .font(.system(size: CGFloat(max(16, model.engine.fontSize - 10)), weight: .regular))
                .foregroundStyle(Color(red: 1, green: 0.42, blue: 0).opacity(0.9))
                .shadow(color: .black.opacity(0.9), radius: 3)
        }
    }

    private func wrappedText(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width, alignment: .center)
    }

    private var guideLine: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.red.opacity(0.5))
                .frame(height: 2)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.33)
        }
        .allowsHitTesting(false)
    }

}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
