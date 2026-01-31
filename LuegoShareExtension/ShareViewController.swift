//
//  ShareViewController.swift
//  LuegoShareExtension
//
//  Created by Arun Sasidharan on 11/11/25.
//

import UIKit
import os.log

class ShareViewController: UIViewController, UIAdaptivePresentationControllerDelegate {

    private let logger = Logger(subsystem: "com.esoxjem.Luego.ShareExtension", category: "ShareViewController")
    private let successView = SuccessView()

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .overFullScreen
        setupUI()
        processSharedURL()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        if let presentationController = presentationController {
            presentationController.delegate = self
        }

        successView.alpha = 0
        successView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        successView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(successView)

        successView.onDismiss = { [weak self] in
            self?.dismissExtension()
        }

        NSLayoutConstraint.activate([
            successView.topAnchor.constraint(equalTo: view.topAnchor),
            successView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            successView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            successView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func processSharedURL() {
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            completeWithError(message: "No items to share")
            return
        }

        for item in inputItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    handleURLProvider(provider)
                    return
                } else if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    handleTextProvider(provider)
                    return
                }
            }
        }

        completeWithError(message: "No URL found")
    }

    private func handleURLProvider(_ provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: "public.url", options: nil) { @Sendable [weak self] (item, error) in
            let extractedURL: URL?
            let errorMessage: String?

            if let error {
                self?.logger.error("Failed to load URL from provider: \(error.localizedDescription, privacy: .private)")
                extractedURL = nil
                errorMessage = "Unable to load URL"
            } else if let url = item as? URL {
                if url.scheme == "http" || url.scheme == "https" {
                    extractedURL = url
                    errorMessage = nil
                } else {
                    extractedURL = nil
                    errorMessage = "Only web URLs are supported"
                }
            } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                if url.scheme == "http" || url.scheme == "https" {
                    extractedURL = url
                    errorMessage = nil
                } else {
                    extractedURL = nil
                    errorMessage = "Only web URLs are supported"
                }
            } else {
                extractedURL = nil
                errorMessage = "Invalid URL format"
            }

            self?.processExtractionResult(url: extractedURL, errorMessage: errorMessage)
        }
    }

    private func handleTextProvider(_ provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { @Sendable [weak self] (item, error) in
            let extractedURL: URL?
            let errorMessage: String?

            if let error {
                self?.logger.error("Failed to load text from provider: \(error.localizedDescription, privacy: .private)")
                extractedURL = nil
                errorMessage = "Unable to load content"
            } else if let text = item as? String, let url = URL(string: text), url.scheme == "http" || url.scheme == "https" {
                extractedURL = url
                errorMessage = nil
            } else {
                extractedURL = nil
                errorMessage = "No valid URL found in text"
            }

            self?.processExtractionResult(url: extractedURL, errorMessage: errorMessage)
        }
    }

    private func processExtractionResult(url: URL?, errorMessage: String?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let url = url {
                self.saveURL(url)
            } else {
                self.completeWithError(message: errorMessage ?? "Unknown error")
            }
        }
    }

    private func saveURL(_ url: URL) {
        SharedStorage.shared.saveSharedURL(url)
        completeWithSuccess()
    }

    private func completeWithSuccess() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.successView.alpha = 1
            self.successView.transform = .identity
        }
    }

    private func dismissExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func completeWithError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "LuegoShareExtension", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
        })
        self.present(alert, animated: true)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

class SuccessView: UIView {

    private let checkmarkView = CheckmarkView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let dismissButton = UIButton(type: .system)

    var onDismiss: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = .clear

        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkmarkView)

        titleLabel.text = "Saved!"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.text = "Added to Luego"
        subtitleLabel.font = .systemFont(ofSize: 17, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        dismissButton.setTitle("Done", for: .normal)
        dismissButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        dismissButton.backgroundColor = .systemBlue
        dismissButton.setTitleColor(.white, for: .normal)
        dismissButton.layer.cornerRadius = 12
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        addSubview(dismissButton)

        NSLayoutConstraint.activate([
            checkmarkView.centerXAnchor.constraint(equalTo: centerXAnchor),
            checkmarkView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -60),
            checkmarkView.widthAnchor.constraint(equalToConstant: 80),
            checkmarkView.heightAnchor.constraint(equalToConstant: 80),

            titleLabel.topAnchor.constraint(equalTo: checkmarkView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            dismissButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            dismissButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            dismissButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }
}

class CheckmarkView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        let checkmarkPath = UIBezierPath()
        checkmarkPath.move(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.5))
        checkmarkPath.addLine(to: CGPoint(x: rect.width * 0.45, y: rect.height * 0.7))
        checkmarkPath.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.3))

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = checkmarkPath.cgPath
        shapeLayer.strokeColor = UIColor.systemGreen.cgColor
        shapeLayer.lineWidth = 6
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        shapeLayer.fillColor = UIColor.clear.cgColor

        let circleLayer = CAShapeLayer()
        circleLayer.path = UIBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3)).cgPath
        circleLayer.fillColor = UIColor.systemGreen.withAlphaComponent(0.1).cgColor
        circleLayer.strokeColor = UIColor.systemGreen.cgColor
        circleLayer.lineWidth = 3

        layer.addSublayer(circleLayer)
        layer.addSublayer(shapeLayer)
    }
}
