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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                if showNewBundleField {
                    HStack(spacing: 4) {
                        TextField("Bundlenavn\u{2026}", text: $newBundleName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Design.buttonTint)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Design.accent.opacity(0.4), lineWidth: 0.6)
                            )
                            .focused($newBundleFocused)
                            .onSubmit { commitNewBundle() }
                            .frame(maxWidth: 130)

                        Button(action: commitNewBundle) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Design.accent)
                                .padding(4)
                        }
                        .buttonStyle(.plain)

                        Button(action: { cancelNewBundle() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Design.subtleText)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: {
                        showNewBundleField = true
                        newBundleFocused = true
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                            Text("Bundle")
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
                    .help("Lag ny bundle")
                }

                ForEach(sortedBundles) { bundle in
                    bundlePill(bundle)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func bundlePill(_ bundle: ContextBundle) -> some View {
        let isActive = viewModel.activeContextBundleId == bundle.id
        let urls = viewModel.bundleFileURLs(bundleId: bundle.id)
        let hasFiles = !urls.isEmpty

        ZStack {
            // Visuell stil
            HStack(spacing: 4) {
                if hasFiles {
                    // Liten drag-indikator viser at pillen kan dras
                    Image(systemName: "arrow.up.doc.on.clipboard")
                        .font(.system(size: 8, weight: .medium))
                        .opacity(0.7)
                }
                Text(bundle.name)
                    .font(.system(size: 10, weight: isActive ? .bold : .medium, design: .rounded))
                if bundle.items.count > 0 {
                    Text("\(bundle.items.count)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isActive ? Design.accent.opacity(0.25) : Design.buttonTint)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isActive ? Design.accent : Design.subtleText)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(isActive ? Design.accent.opacity(0.12) : Design.buttonTint)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    isActive ? Design.accent.opacity(0.35) : Design.buttonBorder,
                    lineWidth: 0.5
                )
            )
            .allowsHitTesting(false)

            // Usynlig NSView som fanger klikk + drag oppå pillen
            DraggableCardWrapper(
                urls: urls,
                onClick: { _ in
                    viewModel.setActiveContextBundle(bundle.id)
                }
            )
        }
        .fixedSize()
        .help(hasFiles
              ? "Klikk for å sette aktiv. Dra for å eksportere \(urls.count) fil\(urls.count == 1 ? "" : "er") til en annen app."
              : "Klikk for å sette aktiv")
        .contextMenu {
            Button("Sett som aktiv") {
                viewModel.setActiveContextBundle(bundle.id)
            }
            Button("Gi nytt navn\u{2026}") {
                renamingBundleId = bundle.id
                renameBuffer = bundle.name
            }
            Divider()
            Button("Slett bundle", role: .destructive) {
                withAnimation { viewModel.deleteContextBundle(id: bundle.id) }
            }
        }
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
            bundleHeader(bundle)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    addSnippetButton(bundle)

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
                        VStack(spacing: 4) {
                            ForEach(bundle.items) { item in
                                if case .file(let id, let stashItemId) = item {
                                    fileRow(bundleId: bundle.id, itemId: id, stashItemId: stashItemId)
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

    @ViewBuilder
    private func bundleHeader(_ bundle: ContextBundle) -> some View {
        HStack(spacing: 6) {
            if renamingBundleId == bundle.id {
                TextField("Navn", text: $renameBuffer)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Design.primaryText)
                    .onSubmit { commitRename() }
                Button(action: commitRename) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Design.accent)
                }
                .buttonStyle(.plain)
            } else {
                Text(bundle.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Design.primaryText)

                Text("\(bundle.fileItemCount) fil\(bundle.fileItemCount == 1 ? "" : "er") \u{00B7} \(bundle.textItemCount) snippet\(bundle.textItemCount == 1 ? "" : "s")")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(Design.subtleText.opacity(0.7))
            }

            Spacer()

            if renamingBundleId != bundle.id {
                Button(action: {
                    renamingBundleId = bundle.id
                    renameBuffer = bundle.name
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(Design.subtleText)
                        .frame(width: 22, height: 22)
                        .background(Design.buttonTint)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Gi bundlen nytt navn")

                Button(action: {
                    withAnimation { viewModel.deleteContextBundle(id: bundle.id) }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(Design.subtleText)
                        .frame(width: 22, height: 22)
                        .background(Design.buttonTint)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Slett bundle")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Design.headerSurface)
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

    private func commitRename() {
        guard let id = renamingBundleId else { return }
        viewModel.renameContextBundle(id: id, name: renameBuffer)
        renamingBundleId = nil
        renameBuffer = ""
    }

    /// Drop fra Finder: importer URLs gjennom eksisterende StashItem-flyt,
    /// og legg dem deretter til som file-items i bundlen.
    private func handleDrop(providers: [NSItemProvider], into bundleId: UUID) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async {
                    let beforeIds = Set(viewModel.items.map { $0.id })
                    viewModel.importURLs([url])
                    // importURLs er asynkron — vent et lite øyeblikk og finn nye items
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        let newItems = viewModel.items.filter { !beforeIds.contains($0.id) }
                        for newItem in newItems {
                            viewModel.addFileToBundle(bundleId: bundleId, stashItemId: newItem.id)
                        }
                    }
                }
            }
        }
    }
}
