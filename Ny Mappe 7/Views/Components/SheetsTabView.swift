import SwiftUI

struct SheetsTabView: View {
    @ObservedObject var viewModel: StashViewModel

    var body: some View {
        VStack(spacing: 0) {
            SheetsCollectorView(viewModel: viewModel)

            if viewModel.sheetsRowCount == 0 {
                sheetsEmptyState
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sheetsEmptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Design.accent.opacity(0.10))
                    .frame(width: 100, height: 100)
                    .blur(radius: 25)

                Image(systemName: "tablecells")
                    .font(.system(size: 42, weight: .thin))
                    .foregroundColor(Design.accent.opacity(0.5))
            }
            .frame(height: 90)

            VStack(spacing: 6) {
                Text("Sheets-samler")
                    .font(Design.headingFont)
                    .foregroundColor(Design.primaryText)

                Text("Kopier tekst med \u{2318}C for \u{00E5} fylle kolonner.\nLim rett inn i Google Sheets.")
                    .font(Design.bodyFont)
                    .foregroundColor(Design.subtleText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
