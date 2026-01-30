import SwiftUI
import ImageIO

#if os(iOS)
import UIKit

struct GIFImageView: UIViewRepresentable {
    let gifName: String

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        if let path = Bundle.main.path(forResource: gifName, ofType: "gif"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let source = CGImageSourceCreateWithData(data as CFData, nil) {
            imageView.animationImages = createAnimationImages(from: source)
            imageView.animationDuration = calculateDuration(from: source)
            imageView.startAnimating()
        }

        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}

    private func createAnimationImages(from source: CGImageSource) -> [UIImage] {
        let frameCount = CGImageSourceGetCount(source)
        return (0..<frameCount).compactMap { index in
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }
    }

    private func calculateDuration(from source: CGImageSource) -> TimeInterval {
        let frameCount = CGImageSourceGetCount(source)
        var duration: TimeInterval = 0

        for index in 0..<frameCount {
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
                  let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
                continue
            }

            let frameDuration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double ?? 0.1
            duration += frameDuration
        }

        return duration > 0 ? duration : 1.0
    }
}

#elseif os(macOS)
import AppKit

struct GIFImageView: NSViewRepresentable {
    let gifName: String

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.animates = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.canDrawSubviewsIntoLayer = true

        if let url = Bundle.main.url(forResource: gifName, withExtension: "gif"),
           let image = NSImage(contentsOf: url) {
            imageView.image = image
        }

        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {}
}
#endif
