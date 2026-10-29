import SwiftUI

/// Reusable numeric PIN pad used by parental controls and profile locks.
struct PINEntryView: View {
    var title: String = L("parental.enter_pin")
    var subtitle: String? = nil
    var length: Int = 4
    /// Return `true` when the PIN is accepted. Returning `false` shows the error state.
    var onComplete: (String) -> Bool
    var onCancel: (() -> Void)? = nil

    @State private var digits: String = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var errorText: String?

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(TigerTheme.goldGradient)

                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, Spacing.lg)

            dots
                .offset(x: shakeOffset)

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

            keypad

            if let onCancel {
                Button(L("common.cancel"), action: onCancel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: 420)
    }

    private var dots: some View {
        HStack(spacing: 18) {
            ForEach(0..<length, id: \.self) { index in
                Circle()
                    .fill(index < digits.count ? TigerTheme.brandLight : Color.primary.opacity(0.12))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                    .scaleEffect(index < digits.count ? 1.12 : 1)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: digits.count)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private var keypad: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: Spacing.sm) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: 76, height: 64)
        } else {
            Button {
                handle(key)
            } label: {
                Group {
                    if key == "⌫" {
                        Image(systemName: "delete.left")
                            .font(.title3)
                    } else {
                        Text(key)
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                    }
                }
                .frame(width: 76, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func handle(_ key: String) {
        errorText = nil

        if key == "⌫" {
            if !digits.isEmpty { digits.removeLast() }
            return
        }

        guard digits.count < length else { return }
        digits.append(key)

        if digits.count == length {
            let candidate = digits
            let accepted = onComplete(candidate)
            if !accepted {
                withAnimation(.default) { errorText = L("parental.error.wrong_pin") }
                shake()
                digits = ""
            }
        }
    }

    private func shake() {
        withAnimation(.linear(duration: 0.05).repeatCount(5, autoreverses: true)) {
            shakeOffset = 10
        }
        Task {
            try? await Task.sleep(for: .milliseconds(280))
            withAnimation(.easeOut(duration: 0.1)) { shakeOffset = 0 }
        }
    }
}

/// Full-screen gate shown when Kids Mode or "lock on launch" is active.
struct KidsModeGate<Content: View>: View {
    @ObservedObject var parental: ParentalControlManager = .shared
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if parental.isUnlocked || !parental.kidsModeEnabled {
                content()
            } else {
                ZStack {
                    TigerAuroraBackground()
                    PINEntryView(
                        title: L("parental.kids_gate.title"),
                        subtitle: L("parental.kids_gate.subtitle"),
                        onComplete: { pin in parental.verify(pin: pin) }
                    )
                }
            }
        }
    }
}
