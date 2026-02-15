import SwiftUI

struct EmptyStateView: View {
    var isScreenshotTab: Bool = false
    var language: AppLanguage = .no
    @State private var floatOffset: CGFloat = 0

    private var loc: Loc { Loc(l: language) }

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
                Text(isScreenshotTab ? loc.noScreenshotsYet : loc.dragFilesHere)
                    .font(Design.headingFont)
                    .foregroundColor(Design.primaryText)

                Text(isScreenshotTab ?
                     loc.enableCameraAndScreenshot :
                     loc.orUseButtonsAbove)
                    .font(Design.bodyFont)
                    .foregroundColor(Design.subtleText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal)
        .padding(.top, 6)
    }
}
