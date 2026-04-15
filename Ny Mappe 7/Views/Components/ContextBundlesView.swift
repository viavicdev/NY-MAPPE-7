import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContextBundlesView: View {
    @ObservedObject var viewModel: StashViewModel

    @State private var showNewBundleField = false
    @State private var newBundleName = ""
    @FocusState private var newBundleFocused: Bool
    @State private var renamingBundleId: UUID?
    @State private var renameBuffer = ""
    @FocusState private var isRenameFocused: Bool
    @State private var dropTargeted = false

    private var sortedBundles: [ContextBundle] {
        viewModel.contextBundles.sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(spacing: 0) {
            bundleSelector
            Divider()

            if let bundle = viewModel.activeContextBundle {
                bundleDetail(bundle)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bundle selector (horizontal pills)

    private var bundleSelector: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    if showNewBundleField {
                        HStack(spacing: 4) {
                            TextField("Bundlenavn\u{2026}", text: $newBundleName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 10, design: .rounded))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Design.buttonTint)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Design.accent.opacity(0.4), lineWidth: 0.6)
                                )
                                .focused($newBundleFocused)
                                .onSubmit { commitNewBundle() }
                                .frame(maxWidth: 130)

                            Button(action: commitNewBundle) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Design.accent)
                                    .padding(3)
                            }
                            .buttonStyle(.plain)

                            Button(action: { cancelNewBundle() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Design.subtleText)
                                    .padding(3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.leading, 6)
                    } else {
                        // Kun "+" som f\u{00F8}rste tab-entry
                        Button(action: {
                            showNewBundleField = true
                            newBundleFocused = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Design.accent)
                                .frame(width: 22, height: 22)
                                .background(Design.accent.opacity(0.12))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Design.accent.opacity(0.3), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .help("Lag ny bundle")
                    }

                    ForEach(sortedBundles) { bundle in
                        bundleTab(bundle)
                    }
                }
                .padding(.horizontal, 4)
            }

            // Action-knapper p\u{00E5} h\u{00F8}yre side \u{2014} gjelder aktiv bundle
            if let active = viewModel.activeContextBundle {
                HStack(spacing: 2) {
                    ViewControlsButton(
                        mode: $viewModel.bundlesViewMode,
                        size: $viewModel.bundlesViewSize,
                        onChange: { viewModel.scheduleSave() }
                    )

                    // + meny: legg til snippet eller filer
                    Menu {
                        Button(action: {
                            _ = viewModel.addTextToBundle(bundleId: active.id, title: "", body: "")
                        }) {
                            Label("Tekstsnippet", systemImage: "text.alignleft")
                        }
                        Button(action: {
                            openFilePickerForBundle(bundleId: active.id)
                        }) {
                            Label("Velg filer\u{2026}", systemImage: "doc")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Design.accent)
                            .frame(width: 18, height: 18)
                            .background(Design.accent.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Legg til innhold")

                    Button(action: {
                        withAnimation { viewModel.deleteContextBundle(id: active.id) }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundColor(Design.subtleText)
                            .frame(width: 18, height: 18)
                            .background(Design.buttonTint)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Slett bundle")
                }
                .padding(.trailing, 6)
                .padding(.leading, 4)
            }
        }
        .padding(.vertical, 4)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Design.dividerColor),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private func bundleTab(_ bundle: ContextBundle) -> some View {
        let isActive = viewModel.activeContextBundleId == bundle.id
        let urls = viewModel.bundleFileURLs(bundleId: bundle.id)
        let hasFiles = !urls.isEmpty
        let isRenaming = renamingBundleId == bundle.id

        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 4) {
                    if let icon = bundle.iconName {
                        AppIcon(icon)
                            .frame(width: 10, height: 10)
                    }
                    if isRenaming {
                        TextField("Navn", text: $renameBuffer)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(Design.accent)
                            .focused($isRenameFocused)
                            .onSubmit { commitRenameBundle() }
                            .frame(minWidth: 60, maxWidth: 140)
                    } else {
                        Text(bundle.name)
                            .font(.system(size: 10, weight: isActive ? .bold : .medium, design: .rounded))
                        if bundle.items.count > 0 {
                            Text("\(bundle.items.count)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(isActive ? Design.accent.opacity(0.2) : Design.buttonTint)
                                .clipShape(Capsule())
                        }
                    }
                }
                .foregroundColor(isActive ? Design.accent : Design.subtleText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .allowsHitTesting(isRenaming)

                if !isRenaming {
                    DraggableCardWrapper(
                        urls: urls,
                        onClick: { event in
                            if event.clickCount >= 2 {
                                // Dobbeltklikk \u{2192} start rename
                                startRenameBundle(bundle)
                            } else {
                                viewModel.setActiveContextBundle(bundle.id)
                            }
                        }
                    )
                }
            }

            // Underline-indikator for aktiv tab
            Rectangle()
                .frame(height: 2)
                .foregroundColor(isActive ? Design.accent : Color.clear)
                .cornerRadius(1)
                .padding(.horizontal, 6)
        }
        .fixedSize()
        .help(hasFiles
              ? "Klikk for \u{00E5} sette aktiv. Dra for \u{00E5} eksportere \(urls.count) fil\(urls.count == 1 ? "" : "er") til en annen app."
              : "Klikk for \u{00E5} sette aktiv")
        .contextMenu {
            if !isRenaming {
                Button("Sett som aktiv") {
                    viewModel.setActiveContextBundle(bundle.id)
                }
                Button("Gi nytt navn\u{2026}") {
                    startRenameBundle(bundle)
                }
                Divider()
                Button("Slett bundle", role: .destructive) {
                    withAnimation { viewModel.deleteContextBundle(id: bundle.id) }
                }
            }
        }
    }

    private func startRenameBundle(_ bundle: ContextBundle) {
        viewModel.setActiveContextBundle(bundle.id)
        renamingBundleId = bundle.id
        renameBuffer = bundle.name
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isRenameFocused = true
        }
    }

    private func commitRenameBundle() {
        guard let id = renamingBundleId else { return }
        viewModel.renameContextBundle(id: id, name: renameBuffer)
        renamingBundleId = nil
        renameBuffer = ""
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(Design.accent.opacity(0.5))
            Text("Ingen bundle valgt")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Design.primaryText)
            Text("Lag en bundle for hver kontekst du jobber i \u{2014}\nf.eks. Render, Podcast, Tenketank.")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(Design.subtleText)
                .multilineTextAlignment(.center)
            Button(action: {
                showNewBundleField = true
                newBundleFocused = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                    Text("Lag f\u{00F8}rste bundle")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
            }
            .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Detail (header + items + footer)

    @ViewBuilder
    private func bundleDetail(_ bundle: ContextBundle) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if bundle.textItemCount > 0 {
                        sectionHeader("Snippets", systemImage: "text.alignleft", count: bundle.textItemCount)
                        VStack(spacing: 4) {
                            ForEach(bundle.items) { item in
                                if case .text(let id, let title, let body) = item {
                                    snippetCard(bundleId: bundle.id, itemId: id, title: title, body: body)
                                }
                            }
                        }
                    }

                    if bundle.fileItemCount > 0 {
                        sectionHeader("Filer", systemImage: "doc", count: bundle.fileItemCount)
                        if viewModel.bundlesViewMode == .list {
                            LazyVStack(spacing: 3) {
                                ForEach(bundle.items) { item in
                                    switch item {
                                    case .localFile(let id, let fileName, let sizeBytes, _):
                                        localFileRowCompact(
                                            bundleId: bundle.id,
                                            itemId: id,
                                            fileName: fileName,
                                            sizeBytes: sizeBytes
                                        )
                                    case .file(let id, let stashItemId):
                                        fileRow(bundleId: bundle.id, itemId: id, stashItemId: stashItemId)
                                    case .text:
                                        EmptyView()
                                    }
                                }
                            }
                        } else {
                            // Antall kolonner styrt av size: 4 (liten) \u{2192} 1 (stor)
                            let colCount: Int = {
                                let s = viewModel.bundlesViewSize
                                if s < 0.25 { return 4 }
                                if s < 0.55 { return 3 }
                                if s < 0.85 { return 2 }
                                return 1
                            }()
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: colCount),
                                spacing: 6
                            ) {
                                ForEach(bundle.items) { item in
                                    switch item {
                                    case .localFile(let id, let fileName, let sizeBytes, _):
                                        localFileTile(
                                            bundleId: bundle.id,
                                            itemId: id,
                                            fileName: fileName,
                                            sizeBytes: sizeBytes
                                        )
                                    case .file(let id, let stashItemId):
                                        fileRow(bundleId: bundle.id, itemId: id, stashItemId: stashItemId)
                                    case .text:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    }

                    if bundle.items.isEmpty {
                        bundleEmptyHint
                    }
                }
                .padding(10)
            }
            .background(
                dropTargeted ? Design.accent.opacity(0.06) : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        dropTargeted ? Design.accent.opacity(0.5) : Color.clear,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .padding(6)
            )
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                handleDrop(providers: providers, into: bundle.id)
                return true
            }

            Divider()
            bundleFooter(bundle)
        }
    }

    private func sectionHeader(_ title: String, systemImage: String, count: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Design.accent)
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(Design.primaryText)
            Text("\(count)")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(Design.subtleText)
        }
        .padding(.horizontal, 4)
    }

    private func addSnippetButton(_ bundle: ContextBundle) -> some View {
        Button(action: {
            _ = viewModel.addTextToBundle(bundleId: bundle.id, title: "", body: "")
        }) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                Text("Tekstsnippet")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundColor(Design.subtleText)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Design.buttonTint)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Design.buttonBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func snippetCard(bundleId: UUID, itemId: UUID, title: String, body: String) -> some View {
        let titleBinding = Binding<String>(
            get: { title },
            set: { newVal in viewModel.updateBundleTextItem(bundleId: bundleId, itemId: itemId, title: newVal) }
        )
        let bodyBinding = Binding<String>(
            get: { body },
            set: { newVal in viewModel.updateBundleTextItem(bundleId: bundleId, itemId: itemId, body: newVal) }
        )

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("Tittel\u{2026}", text: titleBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Design.primaryText)
                Spacer()
                Button(action: {
                    withAnimation { viewModel.removeBundleItem(bundleId: bundleId, itemId: itemId) }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundColor(Design.subtleText.opacity(0.6))
                        .padding(3)
                }
                .buttonStyle(.plain)
                .help("Fjern snippet")
            }

            TextEditor(text: bodyBinding)
                .font(.system(size: 10, design: .rounded))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 50, maxHeight: 120)
                .padding(4)
                .background(Design.panelBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .padding(8)
        .background(Design.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7).stroke(Design.borderColor, lineWidth: 0.5)
        )
    }

    /// Kompakt rad-layout for bundle-filer i list-modus.
    @ViewBuilder
    private func localFileRowCompact(bundleId: UUID, itemId: UUID, fileName: String, sizeBytes: Int64) -> some View {
        let sizeStr = ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
        let fileURL = viewModel.persistenceBundleStorageURL(for: bundleId)
            .appendingPathComponent(fileName)
        let ext = (fileName as NSString).pathExtension.lowercased()

        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Design.subtleText.opacity(0.4))
                .frame(width: 12)

            Image(systemName: fileIconName(for: ext))
                .font(.system(size: 11))
                .foregroundColor(fileIconColor(for: ext))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(fileName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Design.primaryText)
                    .lineLimit(1)
                Text(sizeStr)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Design.subtleText.opacity(0.6))
            }

            Spacer()

            Button(action: {
                withAnimation { viewModel.removeBundleItem(bundleId: bundleId, itemId: itemId) }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(Design.subtleText.opacity(0.6))
                    .padding(3)
            }
            .buttonStyle(.plain)
            .help("Fjern fra bundle")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Design.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(Design.borderColor, lineWidth: 0.5)
        )
        .help("Dra inn i en annen app for \u{00E5} overf\u{00F8}re fila")
        .onDrag {
            NSItemProvider(contentsOf: fileURL) ?? NSItemProvider(object: fileURL as NSURL)
        }
    }

    @ViewBuilder
    private func localFileTile(bundleId: UUID, itemId: UUID, fileName: String, sizeBytes: Int64) -> some View {
        let sizeStr = ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
        let fileURL = viewModel.persistenceBundleStorageURL(for: bundleId)
            .appendingPathComponent(fileName)
        let ext = (fileName as NSString).pathExtension.lowercased()
        let icon = fileIconName(for: ext)
        let iconColor = fileIconColor(for: ext)

        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Filikon
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundColor(iconColor)
                        .frame(height: 36)
                    if !ext.isEmpty {
                        Text(ext.uppercased())
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(iconColor.opacity(0.8))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(iconColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // X-knapp \u{00F8}verst til h\u{00F8}yre
                Button(action: {
                    withAnimation { viewModel.removeBundleItem(bundleId: bundleId, itemId: itemId) }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Design.subtleText.opacity(0.7))
                        .frame(width: 14, height: 14)
                        .background(Design.buttonTint)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(3)
                .help("Fjern fra bundle")
            }

            VStack(spacing: 1) {
                Text(fileName)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(Design.primaryText)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                Text(sizeStr)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Design.subtleText.opacity(0.7))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .background(Design.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(Design.borderColor, lineWidth: 0.5)
        )
        .help("Dra inn i en annen app for \u{00E5} overf\u{00F8}re fila")
        .onDrag {
            NSItemProvider(contentsOf: fileURL) ?? NSItemProvider(object: fileURL as NSURL)
        }
    }

    /// Velger et passende SF-Symbol basert p\u{00E5} filendelsen.
    private func fileIconName(for ext: String) -> String {
        switch ext {
        case "pdf": return "doc.richtext.fill"
        case "md", "markdown": return "doc.text.fill"
        case "txt", "rtf": return "doc.plaintext.fill"
        case "doc", "docx", "pages": return "doc.fill"
        case "xls", "xlsx", "csv", "numbers": return "tablecells.fill"
        case "ppt", "pptx", "key", "keynote": return "rectangle.stack.fill"
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp", "svg": return "photo.fill"
        case "mp4", "mov", "avi", "mkv", "webm": return "play.rectangle.fill"
        case "mp3", "wav", "m4a", "flac", "aac": return "waveform"
        case "zip", "rar", "7z", "tar", "gz", "dmg": return "archivebox.fill"
        case "json", "xml", "html", "htm": return "curlybraces"
        case "swift", "py", "js", "ts", "rb", "go", "rs", "c", "cpp", "h", "java": return "chevron.left.forwardslash.chevron.right"
        default: return "doc.fill"
        }
    }

    /// Farge per filtype for litt visuell distinksjon.
    private func fileIconColor(for ext: String) -> Color {
        switch ext {
        case "pdf": return Design.accent
        case "md", "markdown", "txt", "rtf": return Design.primaryText.opacity(0.7)
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp", "svg":
            return Color.blue.opacity(0.75)
        case "mp4", "mov", "avi", "mkv", "webm":
            return Color.pink.opacity(0.75)
        case "mp3", "wav", "m4a", "flac", "aac":
            return Color.purple.opacity(0.75)
        case "zip", "rar", "7z", "tar", "gz", "dmg":
            return Color.orange.opacity(0.75)
        case "doc", "docx", "pages":
            return Color.blue.opacity(0.75)
        case "xls", "xlsx", "csv", "numbers":
            return Color.green.opacity(0.75)
        default:
            return Design.subtleText
        }
    }

    @ViewBuilder
    private func localFileRow(bundleId: UUID, itemId: UUID, fileName: String, sizeBytes: Int64) -> some View {
        let sizeStr = ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
        let fileURL = viewModel.persistenceBundleStorageURL(for: bundleId)
            .appendingPathComponent(fileName)

        HStack(spacing: 6) {
            // Drag-handle ikon — indikerer at rada kan dras
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Design.subtleText.opacity(0.4))
                .frame(width: 12)

            Image(systemName: "doc")
                .font(.system(size: 11))
                .foregroundColor(Design.accent)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(fileName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Design.primaryText)
                    .lineLimit(1)
                Text(sizeStr)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Design.subtleText.opacity(0.6))
            }

            Spacer()

            Button(action: {
                withAnimation { viewModel.removeBundleItem(bundleId: bundleId, itemId: itemId) }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(Design.subtleText.opacity(0.6))
                    .padding(3)
            }
            .buttonStyle(.plain)
            .help("Fjern fra bundle")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Design.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(Design.borderColor, lineWidth: 0.5)
        )
        .help("Dra inn i en annen app for \u{00E5} overf\u{00F8}re fila")
        .onDrag {
            NSItemProvider(contentsOf: fileURL) ?? NSItemProvider(object: fileURL as NSURL)
        }
    }

    @ViewBuilder
    private func fileRow(bundleId: UUID, itemId: UUID, stashItemId: UUID) -> some View {
        let stashItem = viewModel.items.first(where: { $0.id == stashItemId })

        HStack(spacing: 6) {
            Image(systemName: stashItem == nil ? "doc.badge.questionmark" : "doc")
                .font(.system(size: 11))
                .foregroundColor(stashItem == nil ? Design.subtleText.opacity(0.5) : Design.accent)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(stashItem?.fileName ?? "Slettet fil")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(stashItem == nil ? Design.subtleText : Design.primaryText)
                    .lineLimit(1)
                if let stashItem = stashItem {
                    Text(stashItem.formattedSize)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Design.subtleText.opacity(0.6))
                }
            }

            Spacer()

            Button(action: {
                withAnimation { viewModel.removeBundleItem(bundleId: bundleId, itemId: itemId) }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(Design.subtleText.opacity(0.6))
                    .padding(3)
            }
            .buttonStyle(.plain)
            .help("Fjern fra bundle")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Design.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(Design.borderColor, lineWidth: 0.5)
        )
    }

    private var bundleEmptyHint: some View {
        VStack(spacing: 6) {
            Text("Bundlen er tom")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Design.subtleText)
            Text("Dra filer hit fra Finder, eller h\u{00F8}yreklikk p\u{00E5} en fil i Filer-fanen \u{2192} \u{00AB}Legg til i bundle\u{00BB}.")
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(Design.subtleText.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Footer (drag + copy)

    @ViewBuilder
    private func bundleFooter(_ bundle: ContextBundle) -> some View {
        let urls = viewModel.bundleFileURLs(bundleId: bundle.id)
        let hasContent = !bundle.items.isEmpty

        HStack(spacing: 8) {
            if !urls.isEmpty {
                MultiFileDragButton(
                    urls: urls,
                    label: "Dra alle filer (\(urls.count))",
                    icon: "arrow.up.doc.on.clipboard"
                )
            }

            Spacer()

            Button(action: {
                viewModel.copyBundleAsText(bundleId: bundle.id)
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                    Text("Kopier alt tekst")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
            }
            .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))
            .disabled(!hasContent)
            .opacity(hasContent ? 1.0 : 0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Design.headerSurface)
    }

    // MARK: - Actions

    private func commitNewBundle() {
        let trimmed = newBundleName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            viewModel.createContextBundle(name: trimmed)
        }
        cancelNewBundle()
    }

    private func cancelNewBundle() {
        showNewBundleField = false
        newBundleName = ""
    }

    /// Drop fra Finder: kopier filene rett inn i bundle-lagringen.
    /// Bundles er selvstendige \u{2014} filene importeres IKKE til Filer-fanen.
    /// \u{00C5}pner NSOpenPanel for \u{00E5} velge filer som skal kopieres inn i bundlen.
    private func openFilePickerForBundle(bundleId: UUID) {
        let panel = NSOpenPanel()
        panel.title = "Velg filer"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.level = .floating
        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    viewModel.addLocalFileToBundle(bundleId: bundleId, sourceURL: url)
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider], into bundleId: UUID) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async {
                    viewModel.addLocalFileToBundle(bundleId: bundleId, sourceURL: url)
                }
            }
        }
    }
}
