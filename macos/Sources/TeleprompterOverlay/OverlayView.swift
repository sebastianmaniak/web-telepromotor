import SwiftUI
import TeleprompterCore

struct OverlayView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.engine.playing {
                TimelineView(.periodic(from: .now, by: 1.0 / 60.0)) { timeline in
                    OverlayCanvas(model: model, now: timeline.date)
                }
            } else {
                OverlayCanvas(model: model, now: Date())
            }
        }
        .ignoresSafeArea()
    }
}

private struct OverlayCanvas: View {
    @ObservedObject var model: AppModel
    let now: Date
    @State private var lastDragHeight: CGFloat = 0

    var body: some View {
        let _ = model.advanceFrame(at: now)
        GeometryReader { geo in
            let wrapWidth = max(80, geo.size.width - 40)
            ZStack(alignment: .top) {
                Color.clear
                textStack(width: wrapWidth, viewportHeight: geo.size.height)
                    .frame(width: wrapWidth, alignment: .top)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: -model.scrollY)
                    .gesture(drag)
                topFade
                bottomFade
                guideLine
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    .padding(1)
                    .allowsHitTesting(false)
                if model.hudVisible {
                    VStack {
                        Spacer()
                        ControlHUD(model: model)
                            .padding(.bottom, 8)
                    }
                }
            }
            .clipped()
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
                .foregroundStyle(Color.white.opacity(0.45))
        case .say(let text):
            wrappedText(text, width: width)
                .font(.system(size: CGFloat(model.engine.fontSize), weight: .medium))
                .foregroundStyle(Color.white)
                .lineSpacing(CGFloat(model.engine.fontSize) * 0.7)
        case .draw(let text):
            wrappedText(text, width: width)
                .font(.system(size: CGFloat(max(16, model.engine.fontSize - 10)), weight: .regular))
                .foregroundStyle(Color(red: 1, green: 0.42, blue: 0).opacity(0.85))
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

    private var topFade: some View {
        VStack {
            LinearGradient(colors: [Color.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 48)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var bottomFade: some View {
        VStack {
            Spacer()
            LinearGradient(colors: [.clear, Color.black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                .frame(height: 56)
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
