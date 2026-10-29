import SwiftUI

/// إنشاء أو تعديل ملف مستخدم.
struct ProfileEditorView: View {
    /// nil = إنشاء جديد.
    let profile: Profile?
    var onSave: (Profile?) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = ProfileStore.shared

    @State private var name: String = ""
    @State private var avatar: String = Profile.defaultAvatar
    @State private var isKids: Bool = false
    @State private var pinEnabled: Bool = false
    @State private var pin: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    private var isEditing: Bool { profile != nil }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if pinEnabled && pin.count < 4 { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TigerAuroraBackground()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        avatarPreview
                        avatarGrid
                        nameField
                        kidsToggle
                        pinSection
                        Spacer(minLength: Spacing.lg)
                    }
                    .padding(Spacing.lg)
                }
            }
            .navigationTitle(isEditing ? L("profiles.edit") : L("profiles.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save")) { Task { await save() } }
                        .disabled(!canSave || isSaving)
                        .fontWeight(.semibold)
                }
            }
            .alert(L("common.error"), isPresented: $showError) {
                Button(L("common.ok"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear(perform: populate)
        }
    }

    // MARK: - Sections

    private var avatarPreview: some View {
        Image(systemName: avatar)
            .font(.system(size: 56))
            .foregroundStyle(isKids ? TigerTheme.goldGradient : TigerTheme.brandGradient)
            .frame(width: 116, height: 116)
            .background(Circle().fill(.ultraThinMaterial))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            .padding(.top, Spacing.md)
    }

    private var avatarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 5), spacing: Spacing.sm) {
            ForEach(Profile.avatarChoices, id: \.self) { choice in
                Button {
                    avatar = choice
                } label: {
                    Image(systemName: choice)
                        .font(.system(size: 22))
                        .foregroundStyle(avatar == choice ? Color.white : TigerTheme.inkSoft)
                        .frame(width: 52, height: 52)
                        .background(
                            Circle().fill(avatar == choice ? AnyShapeStyle(TigerTheme.brandGradient) : AnyShapeStyle(.ultraThinMaterial))
                        )
                        .overlay(
                            Circle().strokeBorder(avatar == choice ? TigerTheme.gold : Color.white.opacity(0.15), lineWidth: avatar == choice ? 2 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(L("profiles.name"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(TigerTheme.inkSoft)

            TextField(L("profiles.name.placeholder"), text: $name)
                .textInputAutocapitalization(.words)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        }
    }

    private var kidsToggle: some View {
        Toggle(isOn: $isKids) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("profiles.kids_mode"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TigerTheme.ink)
                Text(L("profiles.kids_mode.desc"))
                    .font(.caption)
                    .foregroundStyle(TigerTheme.inkSoft)
            }
        }
        .tint(TigerTheme.gold)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .onChange(of: isKids) { _, newValue in
            if newValue { avatar = Profile.kidsAvatar }
        }
    }

    private var pinSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Toggle(isOn: $pinEnabled) {
                Text(L("profiles.pin_lock"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TigerTheme.ink)
            }
            .tint(TigerTheme.gold)

            if pinEnabled {
                SecureField(L("profiles.pin.placeholder"), text: $pin)
                    .keyboardType(.numberPad)
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(pin.count >= 4 ? TigerTheme.gold.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Logic

    private func populate() {
        guard let profile else { return }
        name = profile.name
        avatar = profile.avatar
        isKids = profile.isKids
        pinEnabled = profile.pinHash != nil
        pin = ""
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if var existing = profile {
            existing.name = trimmed
            existing.avatar = avatar
            existing.isKids = isKids
            await store.update(existing)
            if pinEnabled, pin.count >= 4 {
                _ = await store.setPIN(pin, for: existing)
            } else if !pinEnabled {
                await store.clearPIN(for: existing)
            }
            if let refreshed = store.profiles.first(where: { $0.id == existing.id }) {
                onSave(refreshed)
            } else {
                onSave(existing)
            }
        } else {
            guard let created = await store.create(name: trimmed, avatar: avatar, isKids: isKids) else {
                errorMessage = L("profiles.error.create")
                showError = true
                return
            }
            if pinEnabled, pin.count >= 4 {
                _ = await store.setPIN(pin, for: created)
            }
            let refreshed = store.profiles.first(where: { $0.id == created.id }) ?? created
            onSave(refreshed)
        }
        dismiss()
    }
}
