import AppKit

/// Valgbar hurtigtast for "legg til markert Finder-fil i Filer-fanen".
/// Et kuratert sett kombinasjoner brukeren kan velge mellom i Settings.
/// To-tasters (\u{2325}F / \u{2325}D) er enklest; tre-tasters gir mindre sjanse for kollisjon.
enum FinderImportHotkey: String, CaseIterable, Codable {
    case off
    case optF
    case optD
    case optShiftF
    case ctrlOptF

    /// Symbol-etikett for visning i Settings (\u{2325}=alt \u{2303}=ctrl \u{21E7}=shift).
    var label: String {
        switch self {
        case .off:       return "Av"
        case .optF:      return "\u{2325}F"
        case .optD:      return "\u{2325}D"
        case .optShiftF: return "\u{2325}\u{21E7}F"
        case .ctrlOptF:  return "\u{2303}\u{2325}F"
        }
    }

    // Virtuelle tastekoder (US-layout): D = 2, F = 3.
    private var keyCode: UInt16? {
        switch self {
        case .off:                          return nil
        case .optF, .optShiftF, .ctrlOptF:  return 3
        case .optD:                         return 2
        }
    }

    private var modifiers: NSEvent.ModifierFlags? {
        switch self {
        case .off:                return nil
        case .optF, .optD:        return [.option]
        case .optShiftF:          return [.option, .shift]
        case .ctrlOptF:           return [.control, .option]
        }
    }

    /// keyCode + modifier-flagg for kombinasjonen, eller nil for `.off`.
    /// Brukes av Carbon-hurtigtast-manageren.
    var components: (keyCode: UInt16, modifiers: NSEvent.ModifierFlags)? {
        guard let keyCode = keyCode, let modifiers = modifiers else { return nil }
        return (keyCode, modifiers)
    }
}
