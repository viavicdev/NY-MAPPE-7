import SwiftUI

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(Design.dangerColor)

            Text(message)
                .font(Design.bodyFont)
                .foregroundColor(Design.primaryText)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(Design.CloseButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Design.cornerRadius)
                    .fill(Design.errorBannerBg)
                // Pink/red wash gradient
                RoundedRectangle(cornerRadius: Design.cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [Design.dangerColor.opacity(0.08), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.cornerRadius)
                .stroke(Design.dangerColor.opacity(0.20), lineWidth: 0.5)
        )
        .padding(.horizontal, Design.cardPadding)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
