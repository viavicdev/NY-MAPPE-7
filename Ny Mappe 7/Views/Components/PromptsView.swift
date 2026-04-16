import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PromptsView: View {
    @ObservedObject var viewModel: StashViewModel

    @State private var renamingCategoryId: UUID?
    @State private var renameBuffer: String = ""
    @FocusState private var isRenameFocused: Bool
    @State private var dropTargeted: Bool = false

    private var sortedCategories: [PromptCategory] {
        viewModel.promptCategories.sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(spacing: 0) {
            categoryTiles
            Divider()

            if let category = viewModel.activePromptCategory {
                promptsList(for: category)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Category tiles (icons in rounded squares)

    private var categoryTiles: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(sortedCategories) { category in
                    categoryTile(category)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func categoryTile(_ category: PromptCategory) -> some View {
        let isActive = viewModel.activePromptCategoryId == category.id
        let dragURLs = viewModel.promptCategoryDragURLs(categoryId: category.id)
        let hasContent = !category.prompts.isEmpty

        ZStack {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? Design.accent.opacity(0.15) : Design.buttonTint)
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isActive ? Design.accent.opacity(0.5) : Design.buttonBorder,
                                    lineWidth: isActive ? 1.2 : 0.5
                                )
                        )

                    if let icon = category.iconName {
                        AppIcon(icon)
                            .frame(width: 15, height: 15)
                            .foregroundColor(isActive ? Design.accent : Design.primaryText)
                    } else {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 13))
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
                                    .offset(x: 4, y: -4)
                            }
                            Spacer()
                        }
                        .frame(width: 32, height: 32)
                    }
                }

                Text(category.name)
                    .font(.system(size: 8, weight: isActive ? .bold : .medium, design: .rounded))
                    .foregroundColor(isActive ? Design.accent : Design.subtleText)
                    .lineLimit(1)
            }
            .frame(width: 46)
            .allowsHitTesting(false)

            // Klikk = sett aktiv, drag = eksporter alle prompts som filer
            DraggableCardWrapper(
                urls: dragURLs,
                onClick: { _ in
                    viewModel.setActivePromptCategory(category.id)
                }
            )
        }
        .frame(width: 46)
        .help(hasContent
              ? "Klikk for \u{00E5} \u{00E5}pne. Dra for \u{00E5} eksportere \(category.prompts.count) prompt\(category.prompts.count == 1 ? "" : "s") som filer."
              : "Klikk for \u{00E5} \u{00E5}pne")
        .contextMenu {
            Button("Sett som aktiv") {
                viewModel.setActivePromptCategory(category.id)
            }
            Button("Gi nytt navn\u{2026}") {
                startRename(category)
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
        VStack(spacing: 0) {
            // Header med navn + rename + ny prompt + ny fil
            HStack(spacing: 6) {
                if renamingCategoryId == category.id {
                    TextField("Navn", text: $renameBuffer)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Design.primaryText)
                        .focused($isRenameFocused)
                        .onSubmit { commitRename() }
                    Button(action: commitRename) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Design.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(category.name)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Design.primaryText)
                    Text("\(category.prompts.count) prompt\(category.prompts.count == 1 ? "" : "s")")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(Design.subtleText.opacity(0.7))
                }

                Spacer()

                // + Fil-knapp (m\u{00E5}per til open-panel)
                Button(action: {
                    openFilePickerForPrompt(categoryId: category.id)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Fil")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(Design.subtleText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Design.buttonTint)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Design.buttonBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .help("Legg til en md-, txt- eller pdf-fil som prompt")

                Button(action: {
                    _ = viewModel.addPrompt(categoryId: category.id)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Prompt")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(Design.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Design.accent.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Design.accent.opacity(0.3), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Design.headerSurface)

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
                            Text("Dra md-, txt- eller pdf-filer hit, eller klikk \u{00AB}+ Prompt\u{00BB} for \u{00E5} skrive en.")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(Design.subtleText.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
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
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 200, alignment: .top)
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

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                TextField("Tittel\u{2026}", text: titleBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Design.primaryText)

                Spacer()

                Button(action: {
                    viewModel.copyPrompt(categoryId: categoryId, promptId: prompt.id)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                        Text("Kopier")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Design.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Design.accent.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(prompt.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

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
                .frame(minHeight: 50, maxHeight: 140)
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
            // Drag-handle
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

            // Kopi (for md/txt) eller info (for pdf)
            if prompt.isTextFile {
                Button(action: {
                    viewModel.copyPrompt(categoryId: categoryId, promptId: prompt.id)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                        Text("Kopier tekst")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Design.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
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

    /// Drop fra Finder: kopier filene inn i kategori-lagringen som fil-prompts.
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

    /// \u{00C5}pner NSOpenPanel for \u{00E5} velge md/txt/pdf-filer som skal legges til i kategorien.
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
}
