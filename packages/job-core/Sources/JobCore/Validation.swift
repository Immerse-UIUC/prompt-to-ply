import AppKit
import Foundation
import ImageIO

public enum ValidationSeverity: String, Codable, Sendable {
    case blocking
    case advisory
}

public struct ValidationCheck: Codable, Equatable, Sendable {
    public var name: String
    public var passed: Bool
    public var severity: ValidationSeverity
    public var detail: String?

    public init(name: String, passed: Bool, severity: ValidationSeverity = .blocking, detail: String? = nil) {
        self.name = name
        self.passed = passed
        self.severity = severity
        self.detail = detail
    }
}

public struct ValidationReport: Codable, Equatable, Sendable {
    public var artifactPath: String
    public var passed: Bool
    public var checks: [ValidationCheck]

    public init(artifactPath: String, checks: [ValidationCheck]) {
        self.artifactPath = artifactPath
        self.checks = checks
        self.passed = checks.filter { $0.severity == .blocking }.allSatisfy(\.passed)
    }
}

public struct ImageMetadata: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var uniformTypeIdentifier: String?

    public init(width: Int, height: Int, uniformTypeIdentifier: String?) {
        self.width = width
        self.height = height
        self.uniformTypeIdentifier = uniformTypeIdentifier
    }
}

public struct ImageValidationReport: Codable, Equatable, Sendable {
    public var validation: ValidationReport
    public var metadata: ImageMetadata?

    public init(validation: ValidationReport, metadata: ImageMetadata?) {
        self.validation = validation
        self.metadata = metadata
    }
}

public enum ImageValidationKind: Sendable {
    case still
    case panoramaEquirectangular
}

public enum ImageValidator {
    public static func validate(url: URL, kind: ImageValidationKind = .still) -> ImageValidationReport {
        var checks: [ValidationCheck] = []
        let fileExists = FileManager.default.fileExists(atPath: url.path)
        checks.append(ValidationCheck(name: "file_exists", passed: fileExists, detail: url.path))

        guard fileExists else {
            return ImageValidationReport(validation: ValidationReport(artifactPath: url.path, checks: checks), metadata: nil)
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            checks.append(ValidationCheck(name: "decode_source", passed: false, detail: "ImageIO could not open image source"))
            return ImageValidationReport(validation: ValidationReport(artifactPath: url.path, checks: checks), metadata: nil)
        }

        let imageCount = CGImageSourceGetCount(source)
        checks.append(ValidationCheck(name: "decode_source", passed: imageCount > 0, detail: "frames=\(imageCount)"))

        guard
            imageCount > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            checks.append(ValidationCheck(name: "dimensions_present", passed: false, detail: "Missing pixel width or height"))
            return ImageValidationReport(validation: ValidationReport(artifactPath: url.path, checks: checks), metadata: nil)
        }

        let metadata = ImageMetadata(width: width, height: height, uniformTypeIdentifier: CGImageSourceGetType(source) as String?)
        checks.append(ValidationCheck(name: "dimensions_non_zero", passed: width > 0 && height > 0, detail: "\(width)x\(height)"))

        if case .panoramaEquirectangular = kind {
            let isTwoToOne = width == height * 2
            checks.append(ValidationCheck(name: "equirectangular_2_to_1", passed: isTwoToOne, detail: "\(width)x\(height)"))
            checks.append(ValidationCheck(name: "seam_heuristic", passed: true, severity: .advisory, detail: "Not implemented yet"))
            checks.append(ValidationCheck(name: "horizon_heuristic", passed: true, severity: .advisory, detail: "Not implemented yet"))
        }

        return ImageValidationReport(validation: ValidationReport(artifactPath: url.path, checks: checks), metadata: metadata)
    }
}

public struct PLYValidationReport: Codable, Equatable, Sendable {
    public var validation: ValidationReport
    public var fileSize: UInt64?

    public init(validation: ValidationReport, fileSize: UInt64?) {
        self.validation = validation
        self.fileSize = fileSize
    }
}

public enum PLYValidator {
    public static func validate(url: URL) -> PLYValidationReport {
        var checks: [ValidationCheck] = []
        let fileExists = FileManager.default.fileExists(atPath: url.path)
        checks.append(ValidationCheck(name: "file_exists", passed: fileExists, detail: url.path))

        guard fileExists else {
            return PLYValidationReport(validation: ValidationReport(artifactPath: url.path, checks: checks), fileSize: nil)
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes?[.size] as? UInt64
        checks.append(ValidationCheck(name: "file_non_empty", passed: (fileSize ?? 0) > 0, detail: "bytes=\(fileSize ?? 0)"))

        let data = (try? Data(contentsOf: url)) ?? Data()
        let prefix = String(decoding: data.prefix(4096), as: UTF8.self)
        checks.append(ValidationCheck(name: "header_starts_with_ply", passed: prefix.hasPrefix("ply"), detail: nil))
        checks.append(ValidationCheck(name: "header_has_end", passed: prefix.contains("end_header"), detail: nil))
        checks.append(ValidationCheck(name: "header_has_element", passed: prefix.contains("element "), detail: nil))

        return PLYValidationReport(validation: ValidationReport(artifactPath: url.path, checks: checks), fileSize: fileSize)
    }
}

public enum ContactSheetWriter {
    public static func write(imageURLs: [URL], outputURL: URL, thumbSize: CGSize = CGSize(width: 256, height: 256), columns: Int = 2) throws {
        let validColumns = max(columns, 1)
        let rows = max(Int(ceil(Double(imageURLs.count) / Double(validColumns))), 1)
        let canvasSize = CGSize(width: CGFloat(validColumns) * thumbSize.width, height: CGFloat(rows) * thumbSize.height)
        let image = NSImage(size: canvasSize)

        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: canvasSize).fill()

        for (index, url) in imageURLs.enumerated() {
            guard let sourceImage = NSImage(contentsOf: url) else {
                continue
            }
            let column = index % validColumns
            let row = index / validColumns
            let rect = NSRect(
                x: CGFloat(column) * thumbSize.width,
                y: canvasSize.height - CGFloat(row + 1) * thumbSize.height,
                width: thumbSize.width,
                height: thumbSize.height
            )
            sourceImage.draw(in: rect.insetBy(dx: 8, dy: 8), from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        image.unlockFocus()

        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pngData.write(to: outputURL, options: [.atomic])
    }
}
