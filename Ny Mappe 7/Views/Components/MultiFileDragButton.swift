import SwiftUI
import AppKit

/// A button-like view that, when dragged, provides multiple file URLs via NSPasteboard.
struct MultiFileDragButton: View {
    let urls: [URL]
    let label: String
    let icon: String
    var helpText: String = ""

    var body: some View {
        ZStack {
            // Visible SwiftUI layer
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Design.accent.opacity(0.25))
            .foregroundColor(Design.accent)
            .clipShape(RoundedRectangle(cornerRadius: Design.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Design.cornerRadius)
                    .stroke(Design.accent.opacity(0.35), lineWidth: 1)
            )
            .allowsHitTesting(false)

            // Invisible drag source on top
            DragSourceView(urls: urls)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .fixedSize()
        .help(helpText)
    }
}
