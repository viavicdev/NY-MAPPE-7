import AppKit
import Foundation

/// Resultat av å spørre Finder om gjeldende utvalg.
struct FinderSelection {
    let urls: [URL]
    /// nil = OK (urls kan likevel være tom = ingenting markert).
    /// Satt = noe gikk galt (typisk manglende automatiseringstillatelse).
    let errorMessage: String?
}

/// Henter filer som er markert i Finder akkurat nå, via Apple Events.
///
/// Brukes av hurtigtasten for "legg til markert Finder-fil i Filer-fanen".
/// Krever Automation-tillatelse (macOS spør første gang om appen får styre Finder);
/// se NSAppleEventsUsageDescription i Info.plist.
enum FinderBridge {

    static func selectedURLs() -> FinderSelection {
        let source = """
        tell application "Finder"
            set theSelection to selection
            set thePaths to ""
            repeat with anItem in theSelection
                set thePaths to thePaths & POSIX path of (anItem as alias) & linefeed
            end repeat
            return thePaths
        end tell
        """

        guard let script = NSAppleScript(source: source) else {
            return FinderSelection(urls: [], errorMessage: "Kunne ikke kj\u{00F8}re Finder-skriptet")
        }

        var errorDict: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorDict)

        if let errorDict = errorDict {
            let code = (errorDict[NSAppleScript.errorNumber] as? Int) ?? 0
            // -1743 = errAEEventNotPermitted (bruker har ikke tillatt automatisering ennå)
            if code == -1743 {
                return FinderSelection(
                    urls: [],
                    errorMessage: "Mangler tillatelse \u{2014} tillat at appen styrer Finder i Systeminnstillinger \u{2192} Personvern og sikkerhet \u{2192} Automatisering"
                )
            }
            return FinderSelection(urls: [], errorMessage: "Kunne ikke lese Finder-utvalget")
        }

        let joined = descriptor.stringValue ?? ""
        let urls = joined
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }

        return FinderSelection(urls: urls, errorMessage: nil)
    }
}
