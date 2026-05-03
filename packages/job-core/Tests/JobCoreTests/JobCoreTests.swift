import AppKit
import Foundation
import Testing
@testable import JobCore

@Test func legalAndIllegalTransitions() throws {
    let machine = JobStateMachine()
    #expect(machine.canTransition(from: .created, to: .generatingStills))
    #expect(try machine.transition(.created, to: .generatingStills) == .generatingStills)

    do {
        _ = try machine.transition(.created, to: .reconstructionRunning)
        Issue.record("Expected illegal transition to throw")
    } catch let error as JobTransitionError {
        #expect(error == .illegalTransition(from: .created, to: .reconstructionRunning))
    }
}

@Test func manifestRoundTripUsesSchemaStatusValues() throws {
    let manifest = BundleManifest(
        jobId: "job-001",
        status: .bundleWritten,
        prompt: "tiny chair on a tabletop",
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        stillCandidates: [
            StillCandidate(index: 0, backend: "captured", imagePath: "candidates/candidate-000.png", thumbnailPath: "candidates/candidate-000.png")
        ],
        artifacts: .canonical(),
        provenance: ProvenanceRecord(stillGeneration: StillGenerationProvenance(backend: "captured"))
    )

    let data = try ManifestCodec.encode(manifest)
    let json = String(decoding: data, as: UTF8.self)
    #expect(json.contains("\"bundle_written\""))
    #expect(try ManifestCodec.decode(data) == manifest)
}

@Test func imageValidationPassesForSimplePNG() throws {
    let directory = try makeTemporaryDirectory()
    let png = directory.appendingPathComponent("image.png")
    try writePNG(to: png, size: CGSize(width: 16, height: 8))

    let report = ImageValidator.validate(url: png)

    #expect(report.validation.passed)
    #expect(report.metadata?.width == 16)
    #expect(report.metadata?.height == 8)
}

@Test func panoramaValidationRequiresTwoToOne() throws {
    let directory = try makeTemporaryDirectory()
    let square = directory.appendingPathComponent("square.png")
    let panorama = directory.appendingPathComponent("pano.png")
    try writePNG(to: square, size: CGSize(width: 16, height: 16))
    try writePNG(to: panorama, size: CGSize(width: 32, height: 16))

    #expect(!ImageValidator.validate(url: square, kind: .panoramaEquirectangular).validation.passed)
    #expect(ImageValidator.validate(url: panorama, kind: .panoramaEquirectangular).validation.passed)
}

@Test func plyValidation() throws {
    let directory = try makeTemporaryDirectory()
    let ply = directory.appendingPathComponent("output.ply")
    try """
    ply
    format ascii 1.0
    element vertex 1
    property float x
    property float y
    property float z
    end_header
    0 0 0
    """.write(to: ply, atomically: true, encoding: .utf8)

    let report = PLYValidator.validate(url: ply)

    #expect(report.validation.passed)
    #expect((report.fileSize ?? 0) > 0)
}

@Test func bundleLayoutCreationAndValidation() throws {
    let directory = try makeTemporaryDirectory()
    let layout = BundleLayout(rootURL: directory)
    try layout.createDirectories()

    let manifest = BundleManifest(
        jobId: "job-001",
        status: .created,
        prompt: "prompt",
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        artifacts: .canonical(),
        provenance: ProvenanceRecord(stillGeneration: StillGenerationProvenance(backend: "captured"))
    )
    try ManifestCodec.write(manifest, to: layout.manifestURL)

    try layout.validateStructure()
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writePNG(to url: URL, size: CGSize) throws {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else {
        Issue.record("Failed to create bitmap")
        return
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor.red.setFill()
    NSRect(origin: .zero, size: size).fill()
    NSGraphicsContext.restoreGraphicsState()

    guard
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        Issue.record("Failed to create PNG data")
        return
    }
    try pngData.write(to: url)
}
