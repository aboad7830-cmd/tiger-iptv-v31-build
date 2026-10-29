import SwiftUI

/// شاشة اختيار الملف الشخصي — تُعرض عند بدء التطبيق إذا كان هناك أكثر من ملف.
struct ProfilePickerView: View {
    @StateObject private var store = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss

    /// يُستدعى عند اختيار ملف (أو إنشاء واحد).
    var onSelect: (Profile) -> Void

    @State private var editingProfile: Profile?
    @State private var showingCreate = false
    @State private var lockedProfile: Profile?
    @State private var wrongPIN = false

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: Spacing.md)]

    var body: some View {
        ZStack {
            TigerAuroraBackground()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    header

                    LazyVGrid(columns: columns, spacing: Spacing.lg) {
                        ForEach(store.profiles) { profile in
                            profileTile(profile)
                        }
                        addTile
                    }
                    .padding(.horizontal, Spacing.lg)

                    Spacer(minLength: Spacing.xl)
                }
                .padding(.vertical, Spacing.xl)
            }
        }
        .task {
            if store.profiles.isEmpty { await store.load() }
        }
        .sheet(isPresented: $showingCreate) {
            ProfileEditorView(profile: nil) { created in
                if let created { onSelect(created) }
            }
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditorView(profile: profile) { updated in
                if let updated, updated.id == store.activeProfile?.id {
                    onSelect(updated)
                }
            }
        }
        .sheet(item: $lockedProfile) { profile in
            PINEntryView(
                title: L("profiles.enter_pin.title"),
                subtitle: profile.name,
                length: 4,
                onComplete: { pin in
                    let ok = store.verify(pin: pin, for: profile)
                    if ok {
                        store.setActive(profile)
                        lockedProfile = nil
                        onSelect(profile)
                    }
                    return ok
                },
                onCancel: { lockedProfile = nil }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            TigerLogoMark(size: 84, eyeGlow: 0.7)
            Text(L("profiles.title"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(TigerTheme.ink)
            Text(L("profiles.subtitle"))
                .font(.subheadline)
                .foregroundStyle(TigerTheme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Tiles

    private func profileTile(_ profile: Profile) -> some View {
        Button {
            if profile.pinHash != nil {
                lockedProfile = profile
            } else {
                store.setActive(profile)
                onSelect(profile)
            }
        } label: {
            VStack(spacing: Spacing.sm) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: profile.avatar)
                        .font(.system(size: 46))
                        .foregroundStyle(profile.isKids ? TigerTheme.goldGradient : TigerTheme.brandGradient)
                        .frame(width: 96, height: 96)
                        .background(
                            Circle().fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        )

                    if profile.pinHash != nil {
                        Image(systemName: "lock.fill")
                            .font(.caption2.bold())
                            .padding(6)
                            .background(Circle().fill(TigerTheme.gold))
                            .foregroundStyle(.black)
                    }
                }

                Text(profile.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TigerTheme.ink)
                    .lineLimit(1)

                if profile.isKids {
                    Text(L("profiles.kids_badge"))
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(TigerTheme.gold.opacity(0.2)))
                        .foregroundStyle(TigerTheme.gold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(
                        store.activeProfile?.id == profile.id
                            ? TigerTheme.gold.opacity(0.8)
                            : Color.white.opacity(0.12),
                        lineWidth: store.activeProfile?.id == profile.id ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingProfile = profile
            } label: {
                Label(L("profiles.edit"), systemImage: "pencil")
            }
            if store.profiles.count > 1 {
                Button(role: .destructive) {
                    Task { await store.delete(profile) }
                } label: {
                    Label(L("profiles.delete"), systemImage: "trash")
                }
            }
        }
    }

    private var addTile: some View {
        Button {
            showingCreate = true
        } label: {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(TigerTheme.inkSoft)
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))

                Text(L("profiles.add"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TigerTheme.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
        }
        .buttonStyle(.plain)
    }
}
