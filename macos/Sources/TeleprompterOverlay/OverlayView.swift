import SwiftUI
import TeleprompterCore

struct OverlayView: View {
    @ObservedObject var model: AppModel
    @State private var lastDragHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                textStack
                    .offset(y: -model.engine.scrollY)
                    .padding(.horizontal, 20)
                    .frame(width: geo.size.width, alignment: .center)
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
            .onAppear {
                model.engine.viewportWidth = geo.size.width
                model.engine.viewportHeight = geo.size.height
            }
            .onChange(of: geo.size) { _, size in
                model.engine.viewportWidth = size.width
                model.engine.viewportHeight = size.height
            }
        }
        .ignoresSafeArea()
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

    private var textStack: some View {
        VStack(alignment: .center, spacing: 28) {
            Spacer().frame(height: model.engine.viewportHeight * 0.33)
            ForEach(Array(model.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
            Spacer().frame(height: model.engine.viewportHeight * 0.5)
        }
        .background(
            GeometryReader { g in
                Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
            }
        )
        .onPreferenceChange(ContentHeightKey.self) { model.engine.contentHeight = $0 }
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .segment(let title):
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))
                .frame(maxWidth: .infinity)
        case .say(let text):
            Text(text)
                .font(.system(size: CGFloat(model.engine.fontSize), weight: .medium))
                .foregroundStyle(Color.white)
                .lineSpacing(CGFloat(model.engine.fontSize) * 0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        case .draw(let text):
            Text(text)
                .font(.system(size: CGFloat(max(16, model.engine.fontSize - 10)), weight: .regular))
                .foregroundStyle(Color(red: 1, green: 0.42, blue: 0).opacity(0.85))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
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
        value = nextValue()
    }
}
