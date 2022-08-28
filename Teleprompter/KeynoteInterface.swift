import Foundation

class KeynoteInterface {
    enum KeynoteError: Error {
        case scriptFailure(NSDictionary)
    }
    
    private static var presenterNotesScript = NSAppleScript(source: """
        tell application "Keynote"
            get the presenter notes of every slide of front document where skipped is false
        end tell
    """)!
    
    private static var startPresentingScript = NSAppleScript(source: """
        tell application "Keynote"
            start front document from first slide of front document
        end tell
    """)!
    
    private static var stopPresentingScript = NSAppleScript(source: """
        tell application "Keynote"
            stop front document
        end tell
    """)!
    
    private static var showNextScript = NSAppleScript(source: """
        tell application "Keynote"
            show next
        end tell
    """)!
    
    private static var selectFirstSlideScript = NSAppleScript(source: """
        tell application "Keynote"
            set the current slide of the front document to the first slide of the front document
        end tell
    """)!
    
    @discardableResult private static func execute(script: NSAppleScript) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?
        let output = script.executeAndReturnError(&error)
        if error != nil {
            throw KeynoteError.scriptFailure(error!)
        }
        
        return output
    }
    
    static func getPresenterNotes() throws -> [String] {
        let output = try execute(script: presenterNotesScript)
        return (1...output.numberOfItems).map { output.atIndex($0)!.stringValue! }
    }
    
    static func startPresenting() throws {
        /*do {
            try execute(script: stopPresentingScript)
        } catch {}
        try execute(script: startPresentingScript)*/
        
        do {
            try execute(script: startPresentingScript)
        } catch {}
        try execute(script: selectFirstSlideScript)
    }
    
    static func showNext() throws {
        try execute(script: showNextScript)
    }
}
