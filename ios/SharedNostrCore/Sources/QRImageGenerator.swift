import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

#if canImport(UIKit)
import UIKit
public typealias QRImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias QRImage = NSImage
#else
public typealias QRImage = Data
#endif

public enum QRImageGenerator {
    public static func makeQR(from string: String, size: CGFloat = 200) -> QRImage? {
        let data = string.data(using: .utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }

        let scale = size / outputImage.extent.size.width
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

#if canImport(UIKit)
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
#elseif canImport(AppKit)
        let rep = NSCIImageRep(ciImage: transformed)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
#else
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.pngData()
#endif
    }
}

