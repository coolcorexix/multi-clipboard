import Foundation

struct AppWithTabHelper {
    /// Returns a list of all open tabs in Google Chrome as (title, url) tuples
    static func listAllTabs() -> [(title: String, url: String)] {
        let appleScript = """
        tell application \"Google Chrome\"
            set tabList to {}
            repeat with w in windows
                repeat with t in tabs of w
                    set end of tabList to (title of t) & \"||\" & (URL of t)
                end repeat
            end repeat
            return tabList
        end tell
        """
        return runAppleScriptList(appleScript)
    }

    /// Returns the active tab in Google Chrome as a (title, url) tuple, or nil if not found
    static func getActiveTab(bundleName: String) -> (title: String, url: String)? {
        let appleScript = """
        tell application \"\(bundleName)\"
            set theTab to active tab of front window
            set theTitle to title of theTab
            set theURL to URL of theTab
            return theTitle & \"||\" & theURL
        end tell
        """
        guard let result = runAppleScript(appleScript) else { return nil }
        let parts = result.components(separatedBy: "||")
        print("parts: \(parts)")
        if parts.count == 2 {
            return (title: parts[0], url: parts[1])
        }
        return nil
    }

    // MARK: - Private helpers

    /// Runs an AppleScript and returns the output as a string
    private static func runAppleScript(_ script: String) -> String? {
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Runs an AppleScript that returns a list and parses it into [(title, url)]
    private static func runAppleScriptList(_ script: String) -> [(title: String, url: String)] {
        guard let output = runAppleScript(script) else { return [] }
        // AppleScript returns lists as comma-separated values
        let tabLines = output.components(separatedBy: ", ")
        var result: [(title: String, url: String)] = []
        for tab in tabLines {
            let parts = tab.components(separatedBy: "||")
            if parts.count == 2 {
                result.append((title: parts[0], url: parts[1]))
            }
        }
        return result
    }
} 