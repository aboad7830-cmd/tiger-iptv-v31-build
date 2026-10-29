import SwiftUI

/// Bottom sheet that configures the sleep timer.
struct SleepTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var controller: SleepTimerController = .shared

    private let presets = [15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    header

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.sm)], spacing: Spacing.sm) {
                        ForEach(presets, id: \.self) { minutes in
                            presetButton(minutes)
                        }
                    }

                    Button {
                        controller.startEndOfEpisode()
                        dismiss()
                    } label: {
                        Label(L("sleep.end_of_episode"), systemImage: "text.badge.checkmark")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(TigerSecondaryButtonStyle())

                    if controller.isActive {
                        Button(role: .destructive) {
                            controller.cancel()
                            dismiss()
                        } label: {
                            Label(L("sleep.cancel"), systemImage: "xmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(Spacing.md)
            }
            .navigationTitle(L("sleep.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 34))
                .foregroundStyle(TigerTheme.goldGradient)

            if controller.isActive {
                Text(controller.remainingText.isEmpty ? L("sleep.end_of_episode") : controller.remainingText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(L("sleep.active"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(L("sleep.subtitle"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private func presetButton(_ minutes: Int) -> some View {
        let selected: Bool = {
            if case .countdown(let m) = controller.mode { return m == minutes }
            return false
        }()

        return Button {
            controller.start(minutes: minutes)
            dismiss()
        } label: {
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(L("sleep.minutes_short"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(selected ? TigerTheme.brand.opacity(0.18) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(selected ? TigerTheme.brandLight : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
