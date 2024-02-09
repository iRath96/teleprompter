//
//  TeleprompterApp.swift
//  Teleprompter
//
//  Created by Alexander Rath on 24.08.22.
//

import SwiftUI
import Combine

struct ScheduledAction {
    enum Action {
        case text(String, [Float])
        case nextAnimation
        case nextSlide
    }
    
    let startTime: Float
    let duration: Float
    let action: Action
    
    var endTime: Float {
        get { return startTime + duration }
    }
}

struct ScheduledLine {
    let text: String
    let startTime: Float
    let duration: Float
    
    var endTime: Float {
        get { return startTime + duration }
    }
}

func estimateSchedule(forText text: String) -> ([Float], Float) {
    var schedule: [Float] = .init(repeating: 0, count: text.count)
    var currentTime: Float = 0
    for (index, char) in text.enumerated() {
        schedule[index] = currentTime
        if char.isWhitespace || char == "-" || char == "(" || char == ")" {
            //
        } else if char.isLetter {
            currentTime += 0.06
        } else if char.isPunctuation {
            currentTime += 0.60
        } else if char.isNumber {
            currentTime += 0.20
        }
    }
    
    return (schedule, currentTime)
}

@main
struct TeleprompterApp: App {
    @State private var timer: Cancellable? = nil
    
    @State private var teleprompterModel = TeleprompterModel()
    
    @State private var actions: [ScheduledAction] = []
    @State private var lines: [ScheduledLine] = []
    
    @State private var startTime = CFAbsoluteTimeGetCurrent()
    @State private var nextActionIndex = 0
    @State private var currentLineIndex = 0
    
    @State private var fontStyle: CTFontUIFontType = .application
    
    private var hasRemainingActions: Bool {
        get { return nextActionIndex < actions.count }
    }
    
    private var hasRemainingLines: Bool {
        get { return currentLineIndex < lines.count }
    }
    
    private func startPresenting() {
        startTime = CFAbsoluteTimeGetCurrent() + 5
        nextActionIndex = 0
        currentLineIndex = 0
        
        let queue = DispatchQueue.global(qos: .userInteractive)
        timer?.cancel()
        timer = queue.schedule(after: queue.now, interval: .milliseconds(1000/30)) {
            tick()
        }
    }
    
    private func tick() {
        let currentTime = Float(CFAbsoluteTimeGetCurrent() - startTime)
        
        while hasRemainingActions && currentTime >= actions[nextActionIndex].startTime {
            do {
                try dispatchAction(actions[nextActionIndex].action)
            } catch {
                print(error)
            }
            
            nextActionIndex += 1
        }
        
        while hasRemainingLines && currentTime >= lines[currentLineIndex].endTime {
            currentLineIndex += 1
        }
        
        var shift: CGFloat
        if currentTime >= 0 {
            shift = CGFloat(currentLineIndex)
            
            if hasRemainingLines {
                let currentLine = lines[currentLineIndex]
                shift += CGFloat(
                    (currentTime - currentLine.startTime) / currentLine.duration
                )
            }
        } else {
            shift = CGFloat(currentTime)
        }
        
        DispatchQueue.main.sync {
            guard case .playing = teleprompterModel.state else {
                return
            }
            
            teleprompterModel.shift = shift
            teleprompterModel.currentTime = currentTime
            
            if hasRemainingActions && (nextActionIndex == 0 || actions[nextActionIndex - 1].duration >= 1) {
                teleprompterModel.timeToAnimation = Float(actions[nextActionIndex].startTime - currentTime)
            } else {
                teleprompterModel.timeToAnimation = .infinity
            }
        }
    }
    
    private func dispatchAction(_ action: ScheduledAction.Action) throws {
        switch action {
        case .nextSlide:
            try KeynoteInterface.showNext()
        
        case .nextAnimation:
            try KeynoteInterface.showNext()
        
        default:
            break
        }
    }
    
    private func makeActions() throws {
        actions.removeAll()
        
        var currentTime: Float = 0
        func addAction(_ action: ScheduledAction.Action, withDuration duration: Float = 0) {
            actions.append(ScheduledAction(startTime: currentTime, duration: duration, action: action))
            currentTime += duration
        }
        
        let notes = try KeynoteInterface.getPresenterNotes()
        for (index, note) in notes.enumerated() {
            if index > 0 {
                addAction(.nextSlide, withDuration: 0.60)
            }
            
            for (index, textS) in note.split(separator: "[>]").enumerated() {
                if index > 0 {
                    addAction(.nextAnimation, withDuration: 0.0)
                }
                
                let text = String(textS).trimmingCharacters(in: .whitespacesAndNewlines)
                let (schedule, duration) = estimateSchedule(forText: text)
                addAction(.text(text, schedule), withDuration: duration)
            }
        }
        
        DispatchQueue.main.sync {
            teleprompterModel.duration = currentTime
        }
    }
    
    private func makeLinesFromActions() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.hyphenationFactor = 1.0
        paragraphStyle.alignment = .justified
        paragraphStyle.lineBreakMode = .byWordWrapping
        //paragraphStyle.lineBreakMode = .byCharWrapping
        paragraphStyle.usesDefaultHyphenation = true
        
        let font = CTFont(fontStyle, size: 500 * teleprompterModel.fontScale)
        
        var fullText = ""
        var fullSchedule: [Float] = []
        var currentTime: Float = 0
        
        for action in actions {
            switch action.action {
            case .text(let text, let schedule):
                fullText += text + " "
                fullSchedule += (schedule + [ action.duration ]).map { $0 + currentTime }
                
            default:
                fullText += "• "
                fullSchedule += [ 0, action.duration ].map { $0 + currentTime}
            }
            
            currentTime += action.duration
        }
        
        let attStr = NSMutableAttributedString(string: fullText, attributes: [
            .paragraphStyle: paragraphStyle,
            .languageIdentifier: "en-US",
            .font: font
        ])
        
        let frameSetter = CTFramesetterCreateWithAttributedString(attStr as CFAttributedString)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: 500, height: CGFloat.greatestFiniteMagnitude), transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, attStr.length), path, nil)
        let framedLines = CTFrameGetLines(frame) as! [CTLine]

        lines.removeAll()
        for lineRef in framedLines {
            let lineRange = CTLineGetStringRange(lineRef)
            let range = NSRange(location: lineRange.location, length: lineRange.length)
            
            var lineString = (fullText as NSString).substring(with: range)
            if (lineString.last?.isLetter ?? false) && lineRef != framedLines.last {
                lineString += "-"
            }
            
            let schedule = fullSchedule[lineRange.location..<(lineRange.location + lineRange.length)]
            lines.append(ScheduledLine(
                text: lineString,
                startTime: (schedule.first ?? 0),
                duration: (schedule.last ?? 0) - (schedule.first ?? 0)
            ))
        }
        
        DispatchQueue.main.sync {
            teleprompterModel.lines = lines.enumerated().map { (index, line) in
                TeleprompterModel.Line(id: index, text: line.text)
            }
        }
    }
    
    func startPlaying() {
        teleprompterModel = TeleprompterModel()
        teleprompterModel.state = .playing
        teleprompterModel.shift = -100
        
        let queue = DispatchQueue.global(qos: .userInteractive)
        queue.async {
            do {
                try makeActions()
                makeLinesFromActions()
                
                startPresenting()
                try KeynoteInterface.startPresenting()
            } catch {
                print(error)
            }
        }
    }
    
    func startIdle() {
        teleprompterModel = TeleprompterModel()
        teleprompterModel.start = {
            startPlaying()
        }
        teleprompterModel.state = .paused
        teleprompterModel.currentTime = 0
        teleprompterModel.timeToAnimation = .infinity
        
        let queue = DispatchQueue.global(qos: .userInteractive)
        timer?.cancel()
        timer = queue.schedule(after: queue.now, interval: .milliseconds(500)) {
            do {
                try makeActions()
            } catch {
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: teleprompterModel)
            .onAppear {
                startIdle()
            }
        }
        .windowResizability(.contentSize)
        
        MenuBarExtra("Teleprompter", systemImage: "text.viewfinder") {
            switch teleprompterModel.state {
            case .playing:
                Button("Stop presentation") {
                    startIdle()
                }
                
                Button("Restart presentation") {
                    startPlaying()
                }
            
            case .paused:
                Button("Start presentation") {
                    startPlaying()
                }
            }
        }
    }
}
