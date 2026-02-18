import SwiftUI

struct EmptyStateView: View {
    var isScreenshotTab: Bool = false
    @State private var floatOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Design.accent.opacity(0.10))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)

                Image(systemName: isScreenshotTab ? "camera.viewfinder" : "tray.and.arrow.down")
                    .font(.system(size: 38, weight: .thin))
                    .foregroundColor(Design.accent.opacity(0.5))
                    .offset(y: floatOffset)
            }
            .frame(height: 60)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    floatOffset = -6
                }
            }

            VStack(spacing: 4) {
                Text(isScreenshotTab ? "Ingen screenshots enn\u{00E5}" : "Dra filer hit")
                    .font(Design.headingFont)
                    .foregroundColor(Design.primaryText)

                Text(isScreenshotTab ?
                     "Sl\u{00E5} p\u{00E5} kamera-ikonet og ta et screenshot" :
                     "eller bruk knappene over")
                    .font(Design.bodyFont)
                    .foregroundColor(Design.subtleText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal)
        .padding(.top, 6)
    }
}
