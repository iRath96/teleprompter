//
//  ContentView.swift
//  Teleprompter
//
//  Created by Alexander Rath on 24.08.22.
//

import SwiftUI

public class TeleprompterModel: ObservableObject {
    struct Line: Identifiable {
        let id: Int
        let text: String
    }
    
    @Published var lines: [Line] = []
    @Published var shift: CGFloat = 0
    @Published var fontScale: CGFloat = 0.1
}

struct ContentView: View {
    @ObservedObject var model: TeleprompterModel
    
    var body: some View {
        GeometryReader { geometry in
            let fontSize = geometry.size.width * model.fontScale * (1 - 2 * model.fontScale)
            let font = Font(CTFont(.application, size: fontSize))
            let lineHeight = fontSize * 1.1
            
            ZStack(alignment: .leading) {
                Color.black.ignoresSafeArea()
                
                Text("▶")
                .offset(x: -fontSize * 0.2, y: -fontSize * 0.02)
                .opacity(0.5)
                
                Divider()
                
                VStack(spacing: 0) {
                    ForEach(model.lines) { line in
                        Text(line.text)
                    }
                    .frame(height: lineHeight)
                }
                .frame(height: lineHeight, alignment: .top)
                .frame(maxWidth: .infinity)
                .offset(y: floor(-(model.shift - 0.45) * lineHeight))
                //.animation(.linear(duration: 0.1), value: model.shift)
            }
            .font(font)
            .frame(minWidth: 0, minHeight: 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static func makeModel() -> TeleprompterModel {
        let model = TeleprompterModel()
        model.lines = [
            .init(id: 0, text: "Hello, world!"),
            .init(id: 1, text: "This is a test.")
        ]
        model.shift = 1
        return model
    }
    
    static var previews: some View {
        ContentView(model: makeModel())
        .frame(width: 500, height: 500)
    }
}
