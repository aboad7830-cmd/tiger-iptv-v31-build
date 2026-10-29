import Foundation
import Combine

/// Sleep timer for the player.
///
/// Supports a fixed countdown ("stop in 30 minutes") and an "end of current
/// episode" mode. The controller is intentionally player-agnostic: the player
/// registers `onExpire` and does whatever is appropriate (pause, stop, dismiss).
@MainActor
final class SleepTimerController: ObservableObject {
    static let shared = SleepTimerController()

    enum Mode: Equatable {
        case off
        case countdown(minutes: Int)
        case endOfEpisode
    }

    @Published private(set) var mode: Mode = .off
    @Published private(set) var remaining: TimeInterval = 0

    /// Called on the main actor when the timer fires.
    var onExpire: (() -> Void)?

    private var task: Task<Void, Never>?

    private init() {}

    var isActive: Bool { mode != .off }

    var remainingText: String {
        guard remaining > 0 else { return "" }
        let total = Int(remaining.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start(minutes: Int) {
        guard minutes > 0 else { cancel(); return }
        mode = .countdown(minutes: minutes)
        remaining = TimeInterval(minutes * 60)
        scheduleTicker()
    }

    func startEndOfEpisode() {
        mode = .endOfEpisode
        remaining = 0
        task?.cancel()
        task = nil
    }

    func cancel() {
        task?.cancel()
        task = nil
        mode = .off
        remaining = 0
    }

    /// Called by the player when an episode or movie finishes.
    func handlePlaybackEnded() {
        guard mode == .endOfEpisode else { return }
        fire()
    }

    private func scheduleTicker() {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                guard case .countdown = self.mode else { return }

                self.remaining = max(0, self.remaining - 1)
                if self.remaining <= 0 {
                    self.fire()
                    return
                }
            }
        }
    }

    private func fire() {
        task?.cancel()
        task = nil
        mode = .off
        remaining = 0
        onExpire?()
    }
}
