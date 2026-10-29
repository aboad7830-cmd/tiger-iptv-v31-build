import SwiftUI
import GRDB
import UIKit

// MARK: - Supporting types

private enum SubscriptionField: Hashable {
    case quick, name, url, username, password
}

private enum ConnectionState: Equatable {
    case idle
    case testing
    case success(ConnectionSummary)
    case failure(String)

    var isTesting: Bool { if case .testing = self { return true }; return false }
}

private struct ConnectionSummary: Equatable {
    var serverName: String
    var expiry: String?
    var maxConnections: String?
    var activeConnections: String?
    var isTrial: Bool
}

// MARK: - Main view

/// Redesigned subscription entry screen.
///
/// Goals:
/// - One paste field that accepts a full Xtream URL, an `host user pass` line or a QR payload.
/// - Clear, labelled fields with live validation ticks.
/// - An explicit "Test connection" step that shows the account status before saving.
/// - A single, obvious primary action with a readable progress state.
struct AddPlaylistView: View {
    @Environment(\.dismiss) private var dismiss

    let editingPlaylist: Playlist?

    @FocusState private var focusedField: SubscriptionField?

    @State private var name: String
    @State private var url: String
    @State private var username: String
    @State private var password: String
    @State private var filterAdultContent: Bool

    @State private var quickInput: String = ""
    @State private var didAutoFill = false
    @State private var showPassword = false
    @State private var showQRScanner = false
    @State private var showAdvanced = false

    @State private var connectionState: ConnectionState = .idle
    @State private var isLoading = false
    @State private var progressMessage: String?
    @State private var errorMessage: String?
    @State private var showError = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(editingPlaylist: Playlist? = nil) {
        self.editingPlaylist = editingPlaylist
        _name = State(initialValue: editingPlaylist?.name ?? "")
        _url = State(initialValue: editingPlaylist?.serverURL ?? "")
        _username = State(initialValue: editingPlaylist?.username ?? "")
        _password = State(initialValue: editingPlaylist?.password ?? "")
        _filterAdultContent = State(initialValue: editingPlaylist?.filterAdultContent ?? false)
    }

    // MARK: Validation

    private var trimmedURL: String { url.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedUsername: String { username.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPassword: String { password.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var urlIsValid: Bool {
        PlaylistImportParser.looksLikeHost(trimmedURL) || trimmedURL.lowercased().hasPrefix("http")
    }
    private var usernameIsValid: Bool { trimmedUsername.count >= 1 }
    private var passwordIsValid: Bool { trimmedPassword.count >= 1 }
    private var nameIsValid: Bool { !trimmedName.isEmpty }

    private var canSave: Bool {
        urlIsValid && usernameIsValid && passwordIsValid && nameIsValid && !isLoading
    }

    private var canTest: Bool {
        urlIsValid && usernameIsValid && passwordIsValid && !isLoading && !connectionState.isTesting
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TigerTheme.splashGradient
                    .opacity(0.06)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        header
                        quickImportCard
                        connectionCard
                        advancedCard
                        testCard
                        saveSection
                        privacyNote
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.xxl)
                }
                .scrollDismissesKeyboard(.interactively)

                if isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle(editingPlaylist == nil ? L("add_playlist.xtream.title_new") : L("add_playlist.xtream.title_edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                        .disabled(isLoading)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("common.done")) { focusedField = nil }
                }
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerSheet { code in
                    showQRScanner = false
                    applyQuickInput(code)
                }
            }
            .alert(L("common.error"), isPresented: $showError) {
                Button(L("common.ok"), role: .cancel) { }
            } message: {
                Text(errorMessage ?? L("common.unknown_error"))
            }
            .task {
                // Deep link: tigeriptv://add?url=... يضع الرابط في الحقل السريع تلقائياً.
                if let pending = UserDefaults.standard.string(forKey: "deeplink.pendingSubscription"),
                   !pending.isEmpty {
                    UserDefaults.standard.removeObject(forKey: "deeplink.pendingSubscription")
                    quickInput = pending
                    applyQuickInput(pending, onlyWhenComplete: true)
                }
            }
            .onChange(of: url) { _, _ in resetConnectionState() }
            .onChange(of: username) { _, _ in resetConnectionState() }
            .onChange(of: password) { _, _ in resetConnectionState() }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            TigerLogoMark(size: 64, eyeGlow: 0.8)
                .padding(.top, Spacing.sm)

            Text(L("add_playlist.header.title"))
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)

            Text(L("add_playlist.header.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.sm)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Quick import

    private var quickImportCard: some View {
        TigerGlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label(L("add_playlist.quick.title"), systemImage: "wand.and.stars")
                    .font(.headline)
                    .foregroundStyle(TigerTheme.gold)

                Text(L("add_playlist.quick.desc"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: Spacing.sm) {
                    TextField(L("add_playlist.quick.placeholder"), text: $quickInput, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .focused($focusedField, equals: .quick)
                        .padding(Spacing.sm)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

                    if !quickInput.isEmpty {
                        Button {
                            quickInput = ""
                            didAutoFill = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: Spacing.sm) {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label(L("add_playlist.quick.paste"), systemImage: "doc.on.clipboard")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(TigerSecondaryButtonStyle())

                    Button {
                        focusedField = nil
                        showQRScanner = true
                    } label: {
                        Label(L("add_playlist.quick.scan"), systemImage: "qrcode.viewfinder")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(TigerSecondaryButtonStyle())
                }

                if didAutoFill {
                    Label(L("add_playlist.quick.detected"), systemImage: "checkmark.seal.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(TigerTheme.brandLight)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .onChange(of: quickInput) { _, newValue in
            guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            applyQuickInput(newValue, onlyWhenComplete: true)
        }
    }

    // MARK: Connection details

    private var connectionCard: some View {
        TigerGlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label(L("add_playlist.section.info"), systemImage: "server.rack")
                    .font(.headline)

                fieldRow(
                    title: L("add_playlist.name_placeholder"),
                    hint: L("add_playlist.name.hint"),
                    icon: "tag",
                    isValid: nameIsValid,
                    showTick: !trimmedName.isEmpty
                ) {
                    TextField(L("add_playlist.name_placeholder"), text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .url }
                }

                fieldRow(
                    title: L("add_playlist.server_url"),
                    hint: L("add_playlist.server_url.hint"),
                    icon: "globe",
                    isValid: urlIsValid,
                    showTick: !trimmedURL.isEmpty
                ) {
                    TextField("http://example.com:8080", text: $url)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .url)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .username }
                }

                Divider().opacity(0.4)

                Label(L("add_playlist.section.credentials"), systemImage: "person.badge.key")
                    .font(.headline)

                fieldRow(
                    title: L("add_playlist.username"),
                    hint: L("add_playlist.username.hint"),
                    icon: "person",
                    isValid: usernameIsValid,
                    showTick: !trimmedUsername.isEmpty
                ) {
                    TextField(L("add_playlist.username"), text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }

                fieldRow(
                    title: L("add_playlist.password"),
                    hint: L("add_playlist.password.hint"),
                    icon: "lock",
                    isValid: passwordIsValid,
                    showTick: !trimmedPassword.isEmpty
                ) {
                    HStack(spacing: Spacing.sm) {
                        Group {
                            if showPassword {
                                TextField(L("add_playlist.password"), text: $password)
                            } else {
                                SecureField(L("add_playlist.password"), text: $password)
                            }
                        }
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showPassword ? L("add_playlist.password.hide") : L("add_playlist.password.show"))
                    }
                }
            }
        }
    }

    // MARK: Advanced

    private var advancedCard: some View {
        TigerGlassCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    HStack {
                        Label(L("add_playlist.advanced.title"), systemImage: "slider.horizontal.3")
                            .font(.headline)
                        Spacer()
                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showAdvanced {
                    Toggle(isOn: $filterAdultContent) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("add_playlist.filter_adult"))
                                .font(.subheadline.weight(.medium))
                            Text(L("add_playlist.filter_adult.desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(TigerTheme.brandLight)
                    .padding(.top, Spacing.xs)
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: Test connection

    private var testCard: some View {
        TigerGlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Label(L("add_playlist.test.title"), systemImage: "bolt.horizontal.circle")
                        .font(.headline)
                    Spacer()
                    statusBadge
                }

                switch connectionState {
                case .idle:
                    Text(L("add_playlist.test.desc"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .testing:
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text(L("add_playlist.test.testing"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                case .success(let summary):
                    VStack(alignment: .leading, spacing: 6) {
                        detailRow(L("add_playlist.test.server"), summary.serverName)
                        if let expiry = summary.expiry {
                            detailRow(L("add_playlist.test.expiry"), expiry)
                        }
                        if let max = summary.maxConnections {
                            detailRow(L("add_playlist.test.connections"),
                                      summary.activeConnections.map { "\($0) / \(max)" } ?? max)
                        }
                        if summary.isTrial {
                            Text(L("add_playlist.test.trial"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TigerTheme.gold)
                        }
                    }
                case .failure(let message):
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await testConnection() }
                } label: {
                    HStack {
                        if connectionState.isTesting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text(connectionState.isTesting ? L("add_playlist.test.testing") : L("add_playlist.test.button"))
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(TigerSecondaryButtonStyle())
                .disabled(!canTest)
                .opacity(canTest ? 1 : 0.5)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch connectionState {
        case .idle:
            EmptyView()
        case .testing:
            badge(L("add_playlist.test.badge.testing"), color: .orange, icon: "clock")
        case .success:
            badge(L("add_playlist.test.badge.ok"), color: TigerTheme.brandLight, icon: "checkmark.circle.fill")
        case .failure:
            badge(L("add_playlist.test.badge.fail"), color: .red, icon: "xmark.circle.fill")
        }
    }

    private func badge(_ text: String, color: Color, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: Spacing.sm)
            Text(value)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: Save

    private var saveSection: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                focusedField = nil
                Task { await savePlaylist() }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(editingPlaylist == nil ? L("add_playlist.save.add") : L("add_playlist.save.update"))
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(TigerPrimaryButtonStyle(enabled: canSave))
            .disabled(!canSave)

            if !canSave && !isLoading {
                Text(L("add_playlist.save.requirements"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var privacyNote: some View {
        Label(L("add_playlist.privacy_note"), systemImage: "lock.shield")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: Loading overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                TigerLogoMark(size: 72, eyeGlow: 1)

                ProgressView()
                    .controlSize(.large)

                Text(progressMessage ?? L("add_playlist.verifying"))
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(L("add_playlist.loading.hint"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: 300)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .shadow(radius: 24)
        }
        .transition(.opacity)
    }

    // MARK: Field row helper

    private func fieldRow<Content: View>(
        title: String,
        hint: String,
        icon: String,
        isValid: Bool,
        showTick: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if showTick {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(isValid ? TigerTheme.brandLight : .orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            content()
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(
                            showTick ? (isValid ? TigerTheme.brandLight.opacity(0.6) : Color.orange.opacity(0.6)) : Color.clear,
                            lineWidth: 1
                        )
                )

            Text(hint)
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.85))
        }
    }

    // MARK: - Actions

    private func applyQuickInput(_ raw: String, onlyWhenComplete: Bool = false) {
        guard let parsed = PlaylistImportParser.parse(raw) else { return }

        if onlyWhenComplete {
            // While typing, only auto-fill once we actually have credentials.
            guard !parsed.username.isEmpty, !parsed.password.isEmpty else { return }
        }

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            if !parsed.serverURL.isEmpty { url = parsed.serverURL }
            if !parsed.username.isEmpty { username = parsed.username }
            if !parsed.password.isEmpty { password = parsed.password }
            if trimmedName.isEmpty, let suggested = parsed.suggestedName, !suggested.isEmpty {
                name = suggested
            }
            didAutoFill = true
            focusedField = nil
        }
    }

    private func pasteFromClipboard() {
        guard let string = Pasteboard.string, !string.isEmpty else { return }
        quickInput = string
        applyQuickInput(string)
    }

    private func resetConnectionState() {
        if case .idle = connectionState { return }
        connectionState = .idle
    }

    private func makePlaylist() -> Playlist {
        Playlist(
            id: editingPlaylist?.id ?? UUID(),
            name: trimmedName,
            serverURL: trimmedURL,
            username: trimmedUsername,
            password: trimmedPassword,
            filterAdultContent: filterAdultContent
        )
    }

    private func testConnection() async {
        guard canTest else { return }
        connectionState = .testing

        let playlist = makePlaylist()
        let client = XtreamAPIClient(playlist: playlist)

        do {
            let response = try await client.verify()

            guard let info = response.userInfo, info.auth == 1 else {
                let message = response.userInfo?.message?.isEmpty == false
                    ? response.userInfo!.message!
                    : L("add_playlist.auth_failed")
                connectionState = .failure(message)
                return
            }

            let serverName = response.serverInfo?.url?.isEmpty == false
                ? response.serverInfo!.url!
                : (playlist.serverURL
                    .replacingOccurrences(of: "http://", with: "")
                    .replacingOccurrences(of: "https://", with: ""))

            connectionState = .success(
                ConnectionSummary(
                    serverName: serverName,
                    expiry: Self.formatExpiry(info.expDate),
                    maxConnections: info.maxConnections,
                    activeConnections: info.activeCons,
                    isTrial: info.isTrial == "1"
                )
            )

            if trimmedName.isEmpty, !serverName.isEmpty {
                name = serverName
            }
        } catch {
            connectionState = .failure(Self.friendlyMessage(for: error))
        }
    }

    private func savePlaylist() async {
        guard canSave else { return }

        isLoading = true
        errorMessage = nil
        progressMessage = L("add_playlist.verifying")

        let newPlaylist = makePlaylist()

        let detailsChanged = editingPlaylist == nil ||
            newPlaylist.serverURL != editingPlaylist?.serverURL ||
            newPlaylist.username != editingPlaylist?.username ||
            newPlaylist.password != editingPlaylist?.password ||
            newPlaylist.filterAdultContent != editingPlaylist?.filterAdultContent

        if !detailsChanged {
            do {
                try await AppDatabase.shared.write { db in
                    try newPlaylist.save(db)
                }
                isLoading = false
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
            return
        }

        let client = XtreamAPIClient(playlist: newPlaylist)

        do {
            let response = try await client.verify()

            if response.userInfo?.auth == 1 {
                await syncAndSave(newPlaylist: newPlaylist, client: client)
            } else {
                errorMessage = response.userInfo?.message?.isEmpty == false
                    ? response.userInfo!.message!
                    : L("add_playlist.auth_failed")
                showError = true
                isLoading = false
                progressMessage = nil
            }
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
            showError = true
            isLoading = false
            progressMessage = nil
        }
    }

    private func syncAndSave(newPlaylist: Playlist, client: XtreamAPIClient) async {
        do {
            try await XtreamImporter.syncAndSave(playlist: newPlaylist, client: client) { message in
                self.progressMessage = message
            }

            isLoading = false
            progressMessage = nil
            dismiss()
        } catch {
            errorMessage = L("add_playlist.download_save_error", error.localizedDescription)
            showError = true
            isLoading = false
            progressMessage = nil
        }
    }

    // MARK: - Formatting helpers

    private static func formatExpiry(_ raw: String?) -> String? {
        guard let raw, let timestamp = Double(raw), timestamp > 0 else { return nil }
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func friendlyMessage(for error: Error) -> String {
        if let xtream = error as? XtreamError {
            switch xtream {
            case .invalidURL:
                return L("add_playlist.error.invalid_url")
            case .networkError:
                return L("add_playlist.error.network")
            case .unauthenticated:
                return L("add_playlist.auth_failed")
            case .decodingError:
                return L("add_playlist.error.decoding")
            case .serverError:
                return L("add_playlist.error.server")
            }
        }
        return error.localizedDescription
    }
}

// MARK: - QR sheet

private struct QRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCode: (String) -> Void

    var body: some View {
        NavigationStack {
            QRScannerView { code in
                onCode(code)
            }
            .ignoresSafeArea()
            .navigationTitle(L("add_playlist.quick.scan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AddPlaylistView()
}
