import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PromptsView: View {
    @ObservedObject var viewModel: StashViewModel

    @State private var renamingCategoryId: UUID?
    @State private var renameBuffer: String = ""
    @FocusState private var isRenameFocused: Bool
    @State private var dropTargeted: Bool = false
    @State private var expandedPromptIds: Set<UUID> = []

    private var sortedCategories: [PromptCategory] {
        viewModel.promptCategories.sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(spacing: 0) {
            categoryTiles
                .fixedSize(horizontal: false, vertical: true)

            if let category = viewModel.activePromptCategory {
                promptsList(for: category)
            } else {
                emptyState
            }
        }
    }

    // MARK: - Category tiles (card-style icon buttons)

    private var categoryTiles: some View {
        HStack(spacing: 4) {
            ForEach(sortedCategories) { category in
                categoryTile(category)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func categoryTile(_ category: PromptCategory) -> some View {
        let isActive = viewModel.activePromptCategoryId == category.id
        let dragURLs = viewModel.promptCategoryDragURLs(categoryId: category.id)
        let hasContent = !category.prompts.isEmpty

        ZStack {
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? Design.accent.opacity(0.15) : Design.buttonTint)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isActive ? Design.accent.opacity(0.6) : Design.buttonBorder,
                                    lineWidth: isActive ? 1.5 : 0.5
                                )
                        )

                    if let customPath = category.customIconPath,
                       let nsImage = NSImage(contentsOfFile: customPath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 26, height: 26)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else if let icon = category.iconName {
                        AppIcon(icon)
                            .frame(width: 20, height: 20)
                            .foregroundColor(isActive ? Design.accent : Design.primaryText)
                    } else {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 17))
                            .foregroundColor(isActive ? Design.accent : Design.primaryText)
                    }

                    if category.prompts.count > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                Text("\(category.prompts.count)")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Design.accent))
                                    .offset(x: 5, y: -5)
                            }
                            Spacer()
                        }
                        .frame(width: 40, height: 40)
                    }
                }
                .frame(width: 40, height: 40)

                Text(category.name)
                    .font(.system(size: 9, weight: isActive ? .bold : .medium, design: .rounded))
                    .foregroundColor(isActive ? Design.accent : Design.subtleText)
                    .lineLimit(1)
            }
            .frame(width: 48)
            .allowsHitTesting(false)

            // Klikk = sett aktiv, dobbeltklikk = endre ikon, drag = eksporter prompts
            DraggableCardWrapper(
                urls: dragURLs,
                onClick: { _ in
                    viewModel.setActivePromptCategory(category.id)
                },
                onDoubleClick: {
                    openIconPicker(for: category.id, isPrompt: true)
                }
            )
            .frame(width: 48)
        }
        .frame(width: 48)
        .fixedSize()
        .help(hasContent
              ? "Klikk for \u{00E5} \u{00E5}pne. Dobbeltklikk for \u{00E5} endre ikon. Dra for \u{00E5} eksportere \(category.prompts.count) prompt\(category.prompts.count == 1 ? "" : "s")."
              : "Klikk for \u{00E5} \u{00E5}pne. Dobbeltklikk for \u{00E5} endre ikon.")
        .contextMenu {
            Button("Sett som aktiv") {
                viewModel.setActivePromptCategory(category.id)
            }
            Button("Gi nytt navn\u{2026}") {
                startRename(category)
            }
            Button("Endre ikon\u{2026}") {
                openIconPicker(for: category.id, isPrompt: true)
            }
            if category.customIconPath != nil {
                Button("Fjern custom ikon") {
                    viewModel.clearPromptCategoryCustomIcon(id: category.id)
                }
            }
            Divider()
            Button("Slett kategori", role: .destructive) {
                withAnimation { viewModel.deletePromptCategory(id: category.id) }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            AppIcon("prompt-bank")
                .frame(width: 40, height: 40)
                .foregroundColor(Design.accent.opacity(0.5))
            Text("Ingen kategori valgt")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Design.primaryText)
            Text("Klikk p\u{00E5} en kategori ovenfor for \u{00E5} se prompts.")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(Design.subtleText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Prompts list for active category

    @ViewBuilder
    private func promptsList(for category: PromptCategory) -> some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Inline rename-banner (kun synlig n\u{00E5}r aktiv)
                if renamingCategoryId == category.id {
                    HStack(spacing: 6) {
                        TextField("Navn", text: $renameBuffer)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Design.primaryText)
                            .focused($isRenameFocused)
                            .onSubmit { commitRename() }
                        Button(action: commitRename) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Design.accent)
                        }
                        .buttonStyle(.plain)
                        Button(action: { renamingCategoryId = nil; renameBuffer = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Design.subtleText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .fixedSize(horizontal: false, vertical: true)
                }

                ScrollView {
                    VStack(spacing: 4) {
                        if category.prompts.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.doc")
                                    .font(.system(size: 22, weight: .thin))
                                    .foregroundColor(Design.subtleText.opacity(0.5))
                                Text("Ingen prompts enn\u{00E5}")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(Design.subtleText)
                                Text("Dra md-, txt- eller pdf-filer hit, eller klikk \u{00AB}+\u{00BB} for \u{00E5} legge til.")
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundColor(Design.subtleText.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 6),
                                GridItem(.flexible(), spacing: 6)
                            ], alignment: .leading, spacing: 6) {
                                ForEach(category.prompts) { prompt in
                                    promptCard(categoryId: category.id, prompt: prompt)
                                        .frame(maxHeight: .infinity, alignment: .top)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .padding(.bottom, 52) // plass for floating + knapp
                    .frame(maxWidth: .infinity, alignment: .top)
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
                    handleDrop(providers: providers, into: category.id)
                    return true
                }
            }

            // Floating + meny-knapp nederst til h\u{00F8}yre
            Menu {
                Button(action: {
                    _ = viewModel.addPrompt(categoryId: category.id)
                }) {
                    Label("Ny prompt", systemImage: "plus")
                }
                Button(action: {
                    openFilePickerForPrompt(categoryId: category.id)
                }) {
                    Label("Legg til fil\u{2026}", systemImage: "doc.badge.plus")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Design.accent)
                    .frame(width: 32, height: 32)
                    .background(Design.accent.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Design.accent.opacity(0.3), lineWidth: 0.5))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(12)
            .help("Legg til prompt eller fil")
        }
    }

    @ViewBuilder
    private func promptCard(categoryId: UUID, prompt: Prompt) -> some View {
        if prompt.isFile {
            filePromptCard(categoryId: categoryId, prompt: prompt)
        } else {
            textPromptCard(categoryId: categoryId, prompt: prompt)
        }
    }

    @ViewBuilder
    private func textPromptCard(categoryId: UUID, prompt: Prompt) -> some View {
        let titleBinding = Binding<String>(
            get: { prompt.title },
            set: { viewModel.updatePrompt(categoryId: categoryId, promptId: prompt.id, title: $0) }
        )
        let bodyBinding = Binding<String>(
            get: { prompt.body },
            set: { viewModel.updatePrompt(categoryId: categoryId, promptId: prompt.id, body: $0) }
        )
        let isExpanded = expandedPromptIds.contains(prompt.id)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                TextField("Tittel\u{2026}", text: titleBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Design.primaryText)

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedPromptIds.remove(prompt.id)
                        } else {
                            expandedPromptIds.insert(prompt.id)
                        }
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Design.subtleText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Design.buttonTint)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Kollaps" : "Utvid")

                Button(action: {
                    viewModel.copyPrompt(categoryId: categoryId, promptId: prompt.id)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Design.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Design.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(prompt.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Kopier")

                Button(action: {
                    withAnimation {
                        viewModel.deletePrompt(categoryId: categoryId, promptId: prompt.id)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundColor(Design.subtleText.opacity(0.6))
                        .padding(3)
                }
                .buttonStyle(.plain)
            }

            TextEditor(text: bodyBinding)
                .font(.system(size: 10, design: .rounded))
                .scrollContentBackground(.hidden)
                .frame(minHeight: isExpanded ? 80 : 40, maxHeight: isExpanded ? 300 : 40)
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

    @ViewBuilder
    private func filePromptCard(categoryId: UUID, prompt: Prompt) -> some View {
        let fileName = prompt.fileName ?? ""
        let fileURL = viewModel.persistencePromptStorageURL(for: categoryId)
            .appendingPathComponent(fileName)
        let size = prompt.fileSizeBytes ?? 0
        let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)

        let icon: String = {
            switch prompt.fileExtension {
            case "md", "markdown": return "doc.text"
            case "txt": return "doc.plaintext"
            case "pdf": return "doc.richtext"
            default: return "doc"
            }
        }()

        let titleBinding = Binding<String>(
            get: { prompt.title },
            set: { viewModel.updatePrompt(categoryId: categoryId, promptId: prompt.id, title: $0) }
        )

        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Design.subtleText.opacity(0.4))
                .frame(width: 12)

            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Design.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Tittel\u{2026}", text: titleBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Design.primaryText)
                HStack(spacing: 4) {
                    Text(fileName)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Design.subtleText.opacity(0.8))
                        .lineLimit(1)
                    Text("\u{00B7}")
                        .foregroundColor(Design.subtleText.opacity(0.4))
                    Text(sizeStr)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Design.subtleText.opacity(0.6))
                }
            }

            Spacer(minLength: 0)

            if prompt.isTextFile {
                Button(action: {
                    viewModel.copyPrompt(categoryId: categoryId, promptId: prompt.id)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Design.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Design.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Les filinnholdet og legg p\u{00E5} utklippstavla")
            }

            Button(action: {
                withAnimation {
                    viewModel.deletePrompt(categoryId: categoryId, promptId: prompt.id)
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(Design.subtleText.opacity(0.6))
                    .padding(3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Design.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7).stroke(Design.borderColor, lineWidth: 0.5)
        )
        .help("Dra rada ut av appen for \u{00E5} overf\u{00F8}re fila til en annen app")
        .onDrag {
            NSItemProvider(contentsOf: fileURL) ?? NSItemProvider(object: fileURL as NSURL)
        }
    }

    // MARK: - Actions

    private func startRename(_ category: PromptCategory) {
        renamingCategoryId = category.id
        renameBuffer = category.name
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isRenameFocused = true
        }
    }

    private func commitRename() {
        guard let id = renamingCategoryId else { return }
        viewModel.renamePromptCategory(id: id, name: renameBuffer)
        renamingCategoryId = nil
        renameBuffer = ""
    }

    private func handleDrop(providers: [NSItemProvider], into categoryId: UUID) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async {
                    viewModel.addPromptFile(categoryId: categoryId, sourceURL: url)
                }
            }
        }
    }

    private func openFilePickerForPrompt(categoryId: UUID) {
        let panel = NSOpenPanel()
        panel.title = "Velg filer"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.level = .floating
        var types: [UTType] = [.plainText, .pdf]
        if let md = UTType("net.daringfireball.markdown") { types.append(md) }
        panel.allowedContentTypes = types
        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    viewModel.addPromptFile(categoryId: categoryId, sourceURL: url)
                }
            }
        }
    }

    /// Felles filvelger for custom ikon (PNG/JPG/SVG osv).
    fileprivate func openIconPicker(for id: UUID, isPrompt: Bool) {
        let panel = NSOpenPanel()
        panel.title = "Velg ikon"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.level = .floating
        var types: [UTType] = [.png, .jpeg, .tiff, .gif, .image]
        if let svg = UTType("public.svg-image") { types.append(svg) }
        panel.allowedContentTypes = types
        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                if isPrompt {
                    viewModel.setPromptCategoryCustomIcon(id: id, sourceURL: url)
                } else {
                    viewModel.setContextBundleCustomIcon(id: id, sourceURL: url)
                }
            }
        }
    }
}
