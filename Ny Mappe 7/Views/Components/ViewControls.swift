import SwiftUI

/// Liten ikonknapp som \u{00E5}pner en popover med ViewControls (grid/liste + st\u{00F8}rrelse).
/// Gir renere header ved at sliderne skjules bak en knapp til brukeren vil justere.
struct ViewControlsButton: View {
    @Binding var mode: ViewMode
    @Binding var size: Double
    var hideModeToggle: Bool = false
    var onChange: () -> Void = {}

    @State private var showPopover: Bool = false

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Design.subtleText)
                .frame(width: 22, height: 18)
                .background(Design.buttonTint)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Design.buttonBorder, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help("Visning")
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            ViewControls(
                mode: $mode,
                size: $size,
                hideModeToggle: hideModeToggle,
                onChange: onChange
            )
            .padding(12)
        }
    }
}

/// Kompakt header-kontroll for \u{00E5} bytte mellom grid/liste-visning
/// og justere st\u{00F8}rrelse p\u{00E5} elementene i en fane. Brukes som innhold i
/// `ViewControlsButton`-popoveren.
struct ViewControls: View {
    @Binding var mode: ViewMode
    @Binding var size: Double
    /// Hvis true: skjul grid/liste-toggle (brukes f.eks. for Filsti som kun er liste)
    var hideModeToggle: Bool = false

    @State private var didCommit: Bool = false
    /// Kalles ved hver endring for \u{00E5} trigge save.
    var onChange: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            if !hideModeToggle {
                HStack(spacing: 0) {
                    modeButton(.grid, icon: "square.grid.2x2")
                    modeButton(.list, icon: "list.bullet")
                }
                .background(Design.buttonTint)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Design.buttonBorder, lineWidth: 0.5)
                )
            }

            HStack(spacing: 4) {
                Image(systemName: "minus")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(Design.subtleText.opacity(0.5))
                Slider(value: Binding(
                    get: { size },
                    set: { newVal in
                        size = newVal
                        onChange()
                    }
                ), in: 0...1)
                .controlSize(.mini)
                .frame(width: 60)
                Image(systemName: "plus")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(Design.subtleText.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private func modeButton(_ target: ViewMode, icon: String) -> some View {
        let isActive = mode == target
        Button(action: {
            if mode != target {
                mode = target
                onChange()
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? Design.accent : Design.subtleText.opacity(0.7))
                .frame(width: 22, height: 18)
                .background(isActive ? Design.accent.opacity(0.12) : Color.clear)
        }
        .buttonStyle(.plain)
        .help(target == .grid ? "Rutenett" : "Liste")
    }
}
