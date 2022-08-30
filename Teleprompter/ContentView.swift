//
//  ContentView.swift
//  Teleprompter
//
//  Created by Alexander Rath on 24.08.22.
//

import SwiftUI

extension CGSize {
    var minimum: CGFloat {
        min(width, height)
    }
}

public class TeleprompterModel: ObservableObject {
    struct Line: Identifiable {
        let id: Int
        let text: String
    }
    
    enum State {
    case paused
    case playing
    }
    
    @Published var state: State = .paused
    
    @Published var lines: [Line] = []
    @Published var shift: CGFloat = 0
    @Published var fontScale: CGFloat = 0.1
    
    @Published var currentTime: Float = 0
    @Published var duration: Float = 0
    @Published var timeToAnimation: Float = .infinity
    
    @Published var start: () -> Void = {}
}

func clampIndex<T>(_ x: Int, _ a: [T]) -> Int {
    return max(0, min(a.count, x))
}

struct ContentView: View {
    @ObservedObject var model: TeleprompterModel
    
    var body: some View {
        GeometryReader { geometry in
            let fontSize = geometry.size.width * model.fontScale * (1 - 2 * model.fontScale)
            let font = Font(CTFont(.application, size: fontSize))
            let lineHeight = fontSize * 1.3
            
            let statusFont = Font(CTFont(.application, size: fontSize / 4))
            
            let maxLinesVisible: CGFloat = geometry.size.height / lineHeight
            let textStartIndex = clampIndex(Int(ceil(model.shift - maxLinesVisible / 2 - 1.5)), model.lines)
            let textEndIndex = clampIndex(Int(ceil(model.shift + maxLinesVisible / 2 + 0.5)), model.lines)
            let shift = model.shift - CGFloat(textStartIndex)
            let lines = model.lines[textStartIndex..<textEndIndex]
            
            ZStack(alignment: .leading) {
                Color.black.ignoresSafeArea()
                
                if model.state == .paused {
                    Image(systemName: "play.circle")
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            model.start()
                        }
                } else {
                    Color.white
                        .opacity(0.3)
                        .frame(height: lineHeight)
                        .overlay(Divider(), alignment: .top)
                        .overlay(Divider(), alignment: .center)
                        .overlay(Divider(), alignment: .bottom)
                    
                    VStack(spacing: 0) {
                        ForEach(lines) { line in
                            Text(line.text)
                        }
                        .frame(height: lineHeight)
                    }
                    .frame(height: lineHeight, alignment: .top)
                    .frame(maxWidth: .infinity)
                    .offset(y: floor(-(shift - 0.45) * lineHeight))
                    
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black, location: 0.04),
                            .init(color: .black.opacity(0), location: 0.2),
                            .init(color: .black.opacity(0), location: 0.8),
                            .init(color: .black, location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    if model.timeToAnimation < 4 {
                        let angle = CGFloat(1 - model.timeToAnimation / 4)
                        ZStack(alignment: .center) {
                            Circle()
                                .trim(from: 0, to: angle)
                                .stroke(.white, lineWidth: geometry.size.height * 0.15)
                                .opacity(0.3)
                                .padding(.all, geometry.size.minimum * 0.3)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                
                Text(verbatim: .init(format: "%.1fs / %.1fs", model.currentTime, model.duration, model.timeToAnimation))
                    .font(statusFont)
                    .offset(y: fontSize / 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .foregroundColor(.white)
            .font(font)
            .frame(minWidth: 0, minHeight: 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            //.scaleEffect(x: -1)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static func makeModel(state: TeleprompterModel.State) -> TeleprompterModel {
        let model = TeleprompterModel()
        model.lines = [
            .init(id: 0, text: "Hello, world!"),
            .init(id: 1, text: "This is a great test.")
        ]
        model.state = state
        model.shift = 1
        model.duration = 12.345
        model.timeToAnimation = 0.1
        return model
    }
    
    static var previews: some View {
        ContentView(model: makeModel(state: .paused))
            .frame(width: 500, height: 500)
        ContentView(model: makeModel(state: .playing))
            .frame(width: 600, height: 500)
    }
}
