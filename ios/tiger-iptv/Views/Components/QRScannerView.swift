import SwiftUI
import AVFoundation

#if os(iOS)

/// Minimal QR scanner used by the "add subscription" flow.
/// Wraps `AVCaptureSession` in a `UIViewController` so it behaves correctly
/// inside a SwiftUI sheet on iPhone and iPad.
struct QRScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onCode: (String) -> Void
        private var handled = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        nonisolated func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue,
                  !value.isEmpty else { return }

            Task { @MainActor in
                guard !self.handled else { return }
                self.handled = true
                self.onCode(value)
            }
        }
    }
}

final class ScannerViewController: UIViewController {
    var coordinator: QRScannerView.Coordinator?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let overlayLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        overlayLabel.text = L("scan.qr.hint")
        overlayLabel.textColor = .white
        overlayLabel.font = .systemFont(ofSize: 15, weight: .medium)
        overlayLabel.textAlignment = .center
        overlayLabel.numberOfLines = 2
        overlayLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayLabel)

        NSLayoutConstraint.activate([
            overlayLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            overlayLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            overlayLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28)
        ])

        configureSession()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            overlayLabel.text = L("scan.qr.unavailable")
            return
        }

        session.beginConfiguration()
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            if let coordinator {
                output.setMetadataObjectsDelegate(coordinator, queue: .main)
            }
            output.metadataObjectTypes = [.qr, .ean8, .ean13, .code128]
        }
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { return }
            Task { @MainActor [weak self] in
                self?.startSession()
            }
        }
    }

    private func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    private func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.stopRunning()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}

#else

/// بديل على المنصات التي لا توفّر كاميرا/ماسح QR.
struct QRScannerView: View {
    var onCode: (String) -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(TigerTheme.orange)
            Text("ماسح QR غير متاح على هذا الجهاز.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#endif
