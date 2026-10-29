import SwiftUI

/// إعدادات الرقابة الأبوية: تعيين PIN، وضع الأطفال، إخفاء المحتوى للبالغين، القفل عند التشغيل.
struct ParentalSettingsView: View {
    @StateObject private var manager = ParentalControlManager.shared

    @State private var showingSetPIN = false
    @State private var showingRemovePIN = false
    @State private var pendingPIN: String = ""
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        List {
            Section(header: Text(L("parental.section.pin"))) {
                if manager.isPINSet {
                    Button(role: .destructive) {
                        showingRemovePIN = true
                    } label: {
                        Label(L("parental.remove_pin"), systemImage: "lock.open")
                    }
                } else {
                    Button {
                        showingSetPIN = true
                    } label: {
                        Label(L("parental.set_pin"), systemImage: "lock.fill")
                    }
                }
            }

            Section(header: Text(L("parental.section.mode"))) {
                Toggle(isOn: Binding(
                    get: { manager.kidsModeEnabled },
                    set: { manager.kidsModeEnabled = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("parental.kids_mode"))
                        Text(L("parental.kids_mode.desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!manager.isPINSet)

                Toggle(isOn: $manager.hideAdultContent) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("parental.hide_adult"))
                        Text(L("parental.hide_adult.desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $manager.lockOnLaunch) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("parental.lock_on_launch"))
                        Text(L("parental.lock_on_launch.desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!manager.isPINSet)
            }

            Section {
                Text(L("parental.footer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L("parental.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSetPIN) {
            PINEntryView(
                title: L("parental.set_pin"),
                subtitle: L("parental.set_pin.subtitle"),
                length: 4,
                onComplete: { pin in
                    do {
                        try manager.setPIN(pin)
                        showingSetPIN = false
                        return true
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                        return false
                    }
                },
                onCancel: { showingSetPIN = false }
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showingRemovePIN) {
            PINEntryView(
                title: L("parental.enter_pin"),
                subtitle: L("parental.remove_pin.subtitle"),
                length: 4,
                onComplete: { pin in
                    let ok = manager.verify(pin: pin)
                    if ok {
                        manager.removePIN()
                        showingRemovePIN = false
                    }
                    return ok
                },
                onCancel: { showingRemovePIN = false }
            )
            .presentationDetents([.large])
        }
        .alert(L("common.error"), isPresented: $showingError) {
            Button(L("common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
