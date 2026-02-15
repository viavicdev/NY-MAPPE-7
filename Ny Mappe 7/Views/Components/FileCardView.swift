import SwiftUI
import AppKit

struct FileCardView: View {
    let item: StashItem
    let isSelected: Bool
    var isCompact: Bool = true
    let onTap: (Bool) -> Void
    let onShiftTap: () -> Void
    let onReveal: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .frame(height: isCompact ? 94 : 100)

                if let thumbPath = item.thumbnailPath,
                   let nsImage = NSImage(contentsOfFile: thumbPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: isCompact ? 90 : 96)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .clear, Design.cardBackground.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        )
                } else {
                    fileIcon
                }

                // Extension badge (full mode only)
                if !isCompact {
                    VStack {
                        HStack {
                            Spacer()
                            Text(".\(item.ext)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Spacer()
                    }
                    .padding(6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 94 : 100)
            .clipped()

            // File info
            VStack(alignment: .leading, spacing: isCompact ? 5 : 4) {
                Text(item.fileName)
                    .font(isCompact ? Design.cardTitleFont : .system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Design.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    TypeBadge(category: item.typeCategory)
                    Text(item.formattedSize)
                        .font(Design.captionFont)
                        .foregroundColor(Design.subtleText)
                }

                // Extra info in full mode
                if !isCompact {
                    Text(StashViewModel.relativeTime(from: item.dateAdded))
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(Design.subtleText.opacity(0.7))
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .padding(item.isScreenshot ? 6 : Design.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Design.cardCornerRadius)
                    .fill(isHovered ? Design.cardHoverBackground : Design.cardBackground)
                // Color wash gradient overlay per file type
                RoundedRectangle(cornerRadius: Design.cardCornerRadius)
                    .fill(Design.cardWashGradient(for: item.typeCategory))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Design.cardCornerRadius))
        .overlay(
            // Top accent stripe (category color)
            VStack {
                RoundedRectangle(cornerRadius: Design.cardCornerRadius)
                    .fill(Design.badgeColor(for: item.typeCategory).opacity(isCompact ? 0 : 0.5))
                    .frame(height: 3)
                    .padding(.horizontal, 1)
                Spacer()
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.cardCornerRadius)
                .stroke(
                    isSelected ? Design.accent.opacity(0.7) : Design.borderColor,
                    lineWidth: isSelected ? 2 : 0.5
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.30 : 0.12), radius: isHovered ? 16 : 8, x: 0, y: isHovered ? 6 : 3)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.18), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var fileIcon: some View {
        let iconName: String = {
            switch item.typeCategory {
            case .image: return "photo"
            case .video: return "film"
            case .audio: return "waveform"
            case .document: return "doc.text"
            case .archive: return "archivebox"
            case .other: return "doc"
            }
        }()

        Image(systemName: iconName)
            .font(.system(size: 32, weight: .thin))
            .foregroundColor(Design.badgeColor(for: item.typeCategory).opacity(0.5))
    }
}
