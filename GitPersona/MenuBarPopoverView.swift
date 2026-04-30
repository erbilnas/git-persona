import AppKit
import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(PersonaStore.self) private var store
    @State private var selectedPersonaID: UUID?
    @State private var repoURL: URL?
    @State private var repoRoot: String?
    @State private var localPreview: (String?, String?)?
    @State private var globalPreview: (String?, String?)?
    @State private var errorMessage: String?
    @State private var successFlash: String?
    @State private var successDismissTask: Task<Void, Never>?

    private let applier = GitConfigApplier()
    private let resolver = RepoResolver()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    personaSection
                    repoSection
                    identityPreviewCard
                    successBanner
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.automatic)

            GlassChrome.floatingBar {
                actionButtons
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 388)
        .frame(minHeight: 420, maxHeight: 560)
        .onAppear {
            syncSelectionWithStore()
            if let first = store.lastRepoPaths.first {
                let url = URL(fileURLWithPath: first)
                repoURL = url
                repoRoot = try? resolver.gitTopLevel(forDirectory: url)
                refreshPreviews()
            }
            refreshGlobalPreview()
        }
        .onChange(of: store.personas.count) { _, _ in
            syncSelectionWithStore()
        }
        .onDisappear {
            successDismissTask?.cancel()
            successDismissTask = nil
        }
        .alert("GitPersona", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .symbolRenderingMode(.hierarchical)
                .font(.title)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("GitPersona")
                    .font(.headline)
                Text("Pick a persona, then apply to this repo or globally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text("v\(AppVersion.marketingVersion)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.quaternary)
                .monospacedDigit()
                .textSelection(.enabled)

            Button {
                activateAppAndOpenSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Open Settings to add or edit personas")

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit GitPersona", systemImage: "power")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Quit GitPersona")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 0))
            } else {
                Rectangle().fill(.bar)
            }
        }
    }

    private var personaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Persona", systemImage: "person.2")

            if store.personas.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("You need at least one persona before applying.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        activateAppAndOpenSettings()
                    } label: {
                        Label("Open Settings", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
            } else {
                List(selection: $selectedPersonaID) {
                    ForEach(store.personas) { p in
                        personaRow(p)
                            .tag(Optional(p.id))
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .frame(minHeight: 132, maxHeight: 220)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private func personaRow(_ p: Persona) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(p.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : p.displayName)
                    .font(.body.weight(.medium))

                let email = p.gitUserEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                Text(email.isEmpty ? "No email set" : email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var repoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Repository", systemImage: "folder")

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: repoRoot == nil ? "folder.badge.questionmark" : "folder.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                        .foregroundStyle(repoRoot == nil ? .tertiary : .secondary)
                        .frame(width: 28, alignment: .center)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(repoPathTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(repoRoot == nil ? .secondary : .primary)

                        if let root = repoRoot {
                            Text(root)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .textSelection(.enabled)
                                .help(root)
                        } else {
                            Text("Choose a folder inside your clone so commits use the right local Git config.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)

                    Button {
                        chooseFolder()
                    } label: {
                        Label("Choose…", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Pick any folder inside a Git repository")
                }

                if !recentRepoPaths.isEmpty {
                    Menu {
                        ForEach(recentRepoPaths, id: \.self) { path in
                            Button {
                                let url = URL(fileURLWithPath: path)
                                repoURL = url
                                applyRepoSelection(url)
                            } label: {
                                Text(menuTitle(for: path))
                            }
                            .help(path)
                        }
                    } label: {
                        Label("Recent repos", systemImage: "clock.arrow.circlepath")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(12)
            .background(cardBackground)
        }
        .padding(.horizontal, 12)
    }

    private var recentRepoPaths: [String] {
        store.lastRepoPaths.filter { !$0.isEmpty }
    }

    private var repoPathTitle: String {
        guard let root = repoRoot else { return "No repository selected" }
        let url = URL(fileURLWithPath: root)
        return url.lastPathComponent
    }

    private func menuTitle(for fullPath: String) -> String {
        let url = URL(fileURLWithPath: fullPath)
        let leaf = url.lastPathComponent
        let parent = url.deletingLastPathComponent().lastPathComponent
        if parent.isEmpty || parent == "/" {
            return leaf
        }
        return "\(parent)/\(leaf)"
    }

    private var identityPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Current identity", systemImage: "eye")

            VStack(alignment: .leading, spacing: 0) {
                previewRow(
                    title: "This repo (local)",
                    subtitle: "From .git/config",
                    line: localIdentityDescription,
                    dimmed: repoRoot == nil
                )
                Divider()
                    .padding(.vertical, 8)
                previewRow(
                    title: "Global",
                    subtitle: "~/.gitconfig",
                    line: globalIdentityDescription,
                    dimmed: false
                )
            }
            .padding(12)
            .background(cardBackground)
        }
        .padding(.horizontal, 12)
    }

    private var localIdentityDescription: String {
        guard repoRoot != nil else {
            return "Select a repository to load local values."
        }
        return formattedIdentity(from: localPreview)
    }

    private var globalIdentityDescription: String {
        formattedIdentity(from: globalPreview)
    }

    private func formattedIdentity(from pair: (String?, String?)?) -> String {
        guard let pair else { return "Could not read Git config." }
        let name = (pair.0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (pair.1 ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty, email.isEmpty { return "Not set" }
        if email.isEmpty { return name }
        if name.isEmpty { return email }
        return "\(name) <\(email)>"
    }

    @ViewBuilder
    private var successBanner: some View {
        if let flash = successFlash {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
                Text(flash)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.green.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.2), value: successFlash)
        }
    }

    private func previewRow(
        title: String,
        subtitle: String,
        line: String,
        dimmed: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(line)
                .font(.caption)
                .foregroundStyle(dimmed ? .tertiary : .secondary)
                .textSelection(.enabled)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                applyLocal()
            } label: {
                Label("Apply to repo", systemImage: "folder.badge.gearshape")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canApplyLocal)
            .help(canApplyLocal ? "Writes user.name / user.email to this repo’s local config" : "Select a persona and valid repository")

            Button {
                applyGlobal()
            } label: {
                Label("Apply globally", systemImage: "globe")
            }
            .buttonStyle(.bordered)
            .disabled(!canApplyGlobal)
            .help(canApplyGlobal ? "Writes user.name / user.email to ~/.gitconfig" : "Select a persona first")
        }
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

    private var canApplyLocal: Bool {
        selectedPersona != nil && repoRoot != nil
    }

    private var canApplyGlobal: Bool {
        selectedPersona != nil
    }

    private var selectedPersona: Persona? {
        store.persona(id: selectedPersonaID)
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            .imageScale(.small)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(nsColor: .controlBackgroundColor))
    }

    private func syncSelectionWithStore() {
        if let id = selectedPersonaID, store.persona(id: id) != nil {
            return
        }
        selectedPersonaID = store.personas.first?.id
    }

    private func hostingWindowForOpenPanel() -> NSWindow? {
        if let key = NSApp.keyWindow, key.isVisible {
            return key
        }
        return NSApp.windows.first { $0.isVisible && $0.canBecomeKey }
    }

    private func chooseFolder() {
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
            await Task.yield()

            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Choose folder"
            panel.message = "Select a folder inside your Git repository."
            if let url = repoURL {
                panel.directoryURL = url
            } else if let first = store.lastRepoPaths.first {
                panel.directoryURL = URL(fileURLWithPath: first)
            }

            if let window = hostingWindowForOpenPanel() {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    panel.beginSheetModal(for: window) { response in
                        Task { @MainActor in
                            if response == .OK, let url = panel.url {
                                repoURL = url
                                applyRepoSelection(url)
                            }
                            continuation.resume()
                        }
                    }
                }
            } else if panel.runModal() == .OK, let url = panel.url {
                repoURL = url
                applyRepoSelection(url)
            }
        }
    }

    private func activateAppAndOpenSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.isVisible && window.level == .normal {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func applyRepoSelection(_ url: URL) {
        do {
            let root = try resolver.gitTopLevel(forDirectory: url)
            repoRoot = root
            store.recordRepoPath(root)
            refreshPreviews()
            clearSuccessFlash()
        } catch {
            repoRoot = nil
            errorMessage = error.localizedDescription
        }
    }

    private func refreshPreviews() {
        guard let repoRoot else {
            localPreview = nil
            return
        }
        localPreview = try? applier.readLocalUser(repoRoot: repoRoot)
    }

    private func refreshGlobalPreview() {
        globalPreview = try? applier.readGlobalUser()
    }

    private func applyLocal() {
        guard let persona = selectedPersona, let repoRoot else { return }
        do {
            try applier.applyLocal(persona: persona, repoRoot: repoRoot)
            refreshPreviews()
            showSuccessBanner("Applied \(persona.displayName) to this repo.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyGlobal() {
        guard let persona = selectedPersona else { return }
        do {
            try applier.applyGlobal(persona: persona)
            refreshGlobalPreview()
            showSuccessBanner("Applied \(persona.displayName) globally.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func showSuccessBanner(_ message: String) {
        successDismissTask?.cancel()
        successFlash = message

        successDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                successFlash = nil
            }
        }
    }

    private func clearSuccessFlash() {
        successDismissTask?.cancel()
        successDismissTask = nil
        successFlash = nil
    }
}
