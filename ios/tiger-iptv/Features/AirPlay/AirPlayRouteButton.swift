import SwiftUI
import AVKit
import Combine

#if os(iOS)

/// زر AirPlay الرسمي (AVRoutePickerView) بتنسيق يتناسب مع واجهة TIGER.
struct AirPlayRouteButton: UIViewRepresentable {
    var tint: UIColor = .white

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = tint
        view.activeTintColor = UIColor(TigerTheme.gold)
        view.prioritizesVideoDevices = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tint
    }
}

/// زر مختصر للاستخدام داخل أشرطة أدوات المشغّل.
struct AirPlayButton: View {
    var size: CGFloat = 22

    var body: some View {
        AirPlayRouteButton()
            .frame(width: size + 16, height: size + 16)
            .accessibilityLabel(L("player.airplay"))
    }
}

/// كشف توفّر شاشات AirPlay عبر AVRouteDetector.
@MainActor
final class AirPlayAvailability: ObservableObject {
    static let shared = AirPlayAvailability()
    @Published private(set) var isAvailable = false
    private let detector = AVRouteDetector()

    private init() {
        detector.isRouteDetectionEnabled = true
        isAvailable = detector.multipleRoutesDetected
        NotificationCenter.default.addObserver(
            forName: .AVRouteDetectorMultipleRoutesDetectedDidChange,
            object: detector,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isAvailable = self?.detector.multipleRoutesDetected ?? false
            }
        }
    }
}

#else

/// بديل بسيط على المنصات التي لا توفّر `AVRoutePickerView`.
struct AirPlayButton: View {
    var size: CGFloat = 22
    var body: some View { EmptyView() }
}

#endif
