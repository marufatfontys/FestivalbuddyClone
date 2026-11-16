import Flutter
import UIKit
import VisionKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.festivalbuddy/qr_scanner",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "scanTicketQR" {
        self?.presentNativeQRScanner(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func presentNativeQRScanner(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let rootVC = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows })
        .first(where: { $0.isKeyWindow })?.rootViewController else {
        result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Could not find root view controller", details: nil))
        return
      }

      if #available(iOS 16.0, *), DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
        let scannerVC = TicketQRScannerHostController(result: result)
        scannerVC.modalPresentationStyle = .pageSheet
        rootVC.present(scannerVC, animated: true)
      } else {
        result(FlutterError(code: "UNSUPPORTED", message: "Built-in camera QR scanner not supported on this device", details: nil))
      }
    }
  }
}

@available(iOS 16.0, *)
class TicketQRScannerHostController: UIViewController, DataScannerViewControllerDelegate {
  private let flutterResult: FlutterResult
  private var hasCompleted = false
  private var scanner: DataScannerViewController?

  init(result: @escaping FlutterResult) {
    self.flutterResult = result
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black

    let dataScanner = DataScannerViewController(
      recognizedDataTypes: [.barcode(symbologies: [.qr, .code128, .ean13]), .text()],
      qualityLevel: .balanced,
      recognizesMultipleItems: false,
      isHighFrameRateTrackingEnabled: true,
      isPinchToZoomEnabled: true,
      isGuidanceEnabled: true,
      isHighlightingEnabled: true
    )
    dataScanner.delegate = self
    self.scanner = dataScanner

    addChild(dataScanner)
    dataScanner.view.frame = view.bounds
    dataScanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(dataScanner.view)
    dataScanner.didMove(toParent: self)

    // Top overlay bar with Close button & instruction
    let header = UIView()
    header.backgroundColor = UIColor.black.withAlphaComponent(0.75)
    header.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(header)

    let titleLabel = UILabel()
    titleLabel.text = "Scan Festival Ticket QR or Code"
    titleLabel.textColor = .white
    titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(titleLabel)

    let closeBtn = UIButton(type: .system)
    closeBtn.setTitle("Cancel", for: .normal)
    closeBtn.setTitleColor(.systemPink, for: .normal)
    closeBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
    closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    closeBtn.translatesAutoresizingMaskIntoConstraints = false
    header.addSubview(closeBtn)

    NSLayoutConstraint.activate([
      header.topAnchor.constraint(equalTo: view.topAnchor),
      header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      header.heightAnchor.constraint(equalToConstant: 64),

      titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor, constant: 6),
      titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),

      closeBtn.centerYAnchor.constraint(equalTo: header.centerYAnchor, constant: 6),
      closeBtn.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20)
    ])
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    try? scanner?.startScanning()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    scanner?.stopScanning()
    if !hasCompleted {
      hasCompleted = true
      flutterResult(nil)
    }
  }

  @objc private func closeTapped() {
    if !hasCompleted {
      hasCompleted = true
      scanner?.stopScanning()
      dismiss(animated: true) {
        self.flutterResult(nil)
      }
    }
  }

  func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
    processItem(item)
  }

  func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
    for item in addedItems {
      if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue, !payload.isEmpty {
        completeWithCode(payload)
        return
      }
      if case .text(let text) = item, text.transcript.uppercased().contains("TKT-") {
        completeWithCode(text.transcript)
        return
      }
    }
  }

  private func processItem(_ item: RecognizedItem) {
    switch item {
    case .barcode(let barcode):
      if let payload = barcode.payloadStringValue, !payload.isEmpty {
        completeWithCode(payload)
      }
    case .text(let text):
      completeWithCode(text.transcript)
    @unknown default:
      break
    }
  }

  private func completeWithCode(_ code: String) {
    guard !hasCompleted else { return }
    hasCompleted = true
    scanner?.stopScanning()
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    dismiss(animated: true) {
      self.flutterResult(code)
    }
  }
}

