import AppKit
import Carbon

/// Registrerer en ekte system-hurtigtast via Carbon (RegisterEventHotKey).
///
/// I motsetning til NSEvent globale monitors krever DETTE ingen Accessibility-tillatelse,
/// fyrer uansett hvilket program som er i fokus, og overlever rebuilds (ad-hoc-signering).
/// Brukes for "legg til markert Finder-fil i Filer-fanen".
final class FinderImportHotKeyManager {
    static let shared = FinderImportHotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onTrigger: (() -> Void)?

    private init() {}

    /// Setter handlingen som kj\u{00F8}res n\u{00E5}r hurtigtasten trykkes, og installerer event-handleren \u{00E9}n gang.
    func configure(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        installHandlerIfNeeded()
    }

    /// (Re)registrerer hurtigtasten for valgt kombinasjon. `.off` avregistrerer den.
    func update(to hotkey: FinderImportHotkey) {
        installHandlerIfNeeded()
        unregister()

        guard let comp = hotkey.components else { return }

        var carbonModifiers: UInt32 = 0
        if comp.modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if comp.modifiers.contains(.option)  { carbonModifiers |= UInt32(optionKey) }
        if comp.modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if comp.modifiers.contains(.shift)   { carbonModifiers |= UInt32(shiftKey) }

        let hotKeyID = EventHotKeyID(signature: fourCharCode("NM7F"), id: 1)
        RegisterEventHotKey(
            UInt32(comp.keyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<FinderImportHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onTrigger?()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &handlerRef
        )
    }

    private func fourCharCode(_ string: String) -> FourCharCode {
        var result: FourCharCode = 0
        for byte in string.utf8.prefix(4) {
            result = (result << 8) + FourCharCode(byte)
        }
        return result
    }
}
