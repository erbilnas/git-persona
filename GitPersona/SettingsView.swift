import SwiftUI

struct SettingsView: View {
    @Environment(PersonaStore.self) private var store
    @State private var selection: UUID?
    @State private var personaPendingDeletion: Persona?
    @FocusState private var focusedField: SettingsFocusField?

    private enum SettingsFocusField: Hashable {
        case displayName
        case gitUserName
        case gitEmail
        case signingKey
        case notes
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        // Sidebar: compact default, user-resizable up to a modest cap so the list does not sprawl.
        .navigationSplitViewColumnWidth(min: 176, ideal: 212, max: 260)
        .frame(minWidth: 640, minHeight: 460)
        .onAppear {
            if selection == nil {
                selection = store.personas.first?.id
            }
        }
        .onChange(of: store.personas.count) { _, count in
            if count == 0 {
                selection = nil
            } else if let id = selection, store.persona(id: id) == nil {
                selection = store.personas.first?.id
            }
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(
                get: { personaPendingDeletion != nil },
                set: { if !$0 { personaPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let p = personaPendingDeletion {
                    store.delete(id: p.id)
                    selection = store.personas.first?.id
                }
                personaPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                personaPendingDeletion = nil
            }
        } message: {
            Text("This removes the saved persona from GitPersona. Your Git configs are not changed.")
        }
    }

    private var deleteDialogTitle: String {
        guard let p = personaPendingDeletion else { return "" }
        return "Delete “\(p.displayName)”?"
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            ZStack {
                List(selection: $selection) {
                    Section {
                        ForEach(store.personas) { p in
                            personaSidebarRow(p)
                                .tag(Optional(p.id))
                                .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                                .contextMenu {
                                    Button("Duplicate") {
                                        duplicatePersona(sourceID: p.id)
                                    }
                                    Divider()
                                    Button("Delete…", role: .destructive) {
                                        personaPendingDeletion = p
                                    }
                                }
                        }
                        .onMove { source, destination in
                            store.movePersonas(fromOffsets: source, toOffset: destination)
                        }
                    } header: {
                        Text("Saved personas")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
                .listStyle(.sidebar)
                .environment(\.defaultMinListRowHeight, 52)

                if store.personas.isEmpty {
                    ContentUnavailableView {
                        Label("No personas yet", systemImage: "person.crop.circle.dashed")
                    } description: {
                        Text("Create one to switch Git name, email, and signing options from the menu bar.")
                    } actions: {
                        Button("Add persona") {
                            addPersona()
                        }
                        .keyboardShortcut("n", modifiers: .command)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background.opacity(0.85))
                }
            }

            Divider()

            Text("Version \(AppVersion.fullDescription)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationTitle("GitPersona")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    addPersona()
                } label: {
                    Label("Add persona", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Create a new persona (⌘N)")

                Button {
                    duplicateSelection()
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                .disabled(selection.flatMap { store.persona(id: $0) } == nil)
                .help("Duplicate the selected persona")
            }
            ToolbarItem(placement: .destructiveAction) {
                Button {
                    if let id = selection, let p = store.persona(id: id) {
                        personaPendingDeletion = p
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selection.flatMap { store.persona(id: $0) } == nil)
                .help("Delete the selected persona")
            }
        }
    }

    private func personaSidebarRow(_ p: Persona) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "person.crop.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(p.displayName.isEmpty ? "Untitled persona" : p.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(emailSubtitle(for: p))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private func emailSubtitle(for p: Persona) -> String {
        let e = p.gitUserEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if e.isEmpty {
            return "No email set"
        }
        return e
    }

    @ViewBuilder
    private var detailPane: some View {
        if let id = selection, store.persona(id: id) != nil {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    personaHeaderCard(personaID: id)

                    Form {
                        Section {
                            TextField("Name", text: binding(\.displayName, for: id))
                                .focused($focusedField, equals: .displayName)
                                .textFieldStyle(.roundedBorder)
                        } header: {
                            Text("Label")
                        } footer: {
                            Text("Shown only inside GitPersona to tell personas apart.")
                        }

                        Section {
                            TextField("Ada Lovelace", text: binding(\.gitUserName, for: id))
                                .focused($focusedField, equals: .gitUserName)
                                .textContentType(.name)
                                .textFieldStyle(.roundedBorder)

                            TextField("you@example.com", text: binding(\.gitUserEmail, for: id))
                                .focused($focusedField, equals: .gitEmail)
                                .textContentType(.emailAddress)
                                .textFieldStyle(.roundedBorder)
                        } header: {
                            Text("Git author")
                        } footer: {
                            emailFooter(for: id)
                        }

                        Section {
                            TextField("e.g. ~/.ssh/id_ed25519.pub or key fingerprint", text: optionalBinding(\.signingKey, for: id))
                                .focused($focusedField, equals: .signingKey)
                                .textFieldStyle(.roundedBorder)
                        } header: {
                            Text("Signing key")
                        } footer: {
                            Text("Optional. Written to user.signingkey when you apply this persona.")
                        }

                        Section {
                            TextField("Notes", text: optionalBinding(\.notes, for: id), axis: .vertical)
                                .focused($focusedField, equals: .notes)
                                .lineLimit(4...10)
                                .textFieldStyle(.roundedBorder)
                        } header: {
                            Text("Notes")
                        } footer: {
                            Text("Private to this Mac; not sent to Git.")
                        }
                    }
                    .formStyle(.grouped)
                    .padding(.bottom, 8)
                }
                .padding()
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Persona")
            .navigationSubtitle(store.persona(id: id)?.displayName ?? "")
        } else {
            ContentUnavailableView {
                Label("Choose a persona", systemImage: "arrow.left")
            } description: {
                Text("Select an item in the list, or add a new persona.")
            } actions: {
                Button("Add persona") {
                    addPersona()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    @ViewBuilder
    private func emailFooter(for id: UUID) -> some View {
        let email = store.persona(id: id)?.gitUserEmail ?? ""
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Text("Sets local or global user.email when you apply from the menu bar.")
        } else if !Self.looksLikeEmail(trimmed) {
            Label {
                Text("This does not look like a typical email. Git will still accept it if you intend that.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)
            }
            .font(.footnote)
        } else {
            Text("Sets local or global user.email when you apply from the menu bar.")
        }
    }

    private func personaHeaderCard(personaID: UUID) -> some View {
        let p = store.persona(id: personaID)
        return HStack(alignment: .center, spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(p?.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? (p?.displayName ?? "")
                    : "Untitled persona")
                    .font(.title2.weight(.semibold))

                Text(gitIdentityPreview(for: p))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private func gitIdentityPreview(for p: Persona?) -> String {
        guard let p else { return "—" }
        let n = p.gitUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = p.gitUserEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty, e.isEmpty {
            return "Set Git author fields below"
        }
        if e.isEmpty { return n }
        if n.isEmpty { return e }
        return "\(n) <\(e)>"
    }

    private func addPersona() {
        let p = Persona(
            displayName: "New persona",
            gitUserName: "",
            gitUserEmail: ""
        )
        store.upsert(p)
        selection = p.id
        focusedField = .displayName
    }

    private func duplicateSelection() {
        guard let id = selection else { return }
        duplicatePersona(sourceID: id)
    }

    private func duplicatePersona(sourceID: UUID) {
        if let newID = store.duplicatePersona(id: sourceID) {
            selection = newID
            focusedField = .displayName
        }
    }

    private func binding(_ keyPath: WritableKeyPath<Persona, String>, for id: UUID) -> Binding<String> {
        Binding(
            get: { store.persona(id: id)?[keyPath: keyPath] ?? "" },
            set: { newValue in
                guard var p = store.persona(id: id) else { return }
                p[keyPath: keyPath] = newValue
                store.upsert(p)
            }
        )
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<Persona, String?>, for id: UUID) -> Binding<String> {
        Binding(
            get: { store.persona(id: id)?[keyPath: keyPath] ?? "" },
            set: { newValue in
                guard var p = store.persona(id: id) else { return }
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                p[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
                store.upsert(p)
            }
        )
    }

    /// Lightweight sanity check — Git allows unusual strings; we only nudge the user.
    private static func looksLikeEmail(_ s: String) -> Bool {
        let parts = s.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let domain = String(parts[1])
        return domain.contains(".") && domain.count >= 3
    }
}
