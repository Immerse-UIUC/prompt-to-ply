import Foundation

public enum BundleLayoutError: Error, CustomStringConvertible {
    case manifestMissing(URL)
    case requiredDirectoryMissing(URL)

    public var description: String {
        switch self {
        case let .manifestMissing(url):
            return "Bundle manifest is missing at \(url.path)"
        case let .requiredDirectoryMissing(url):
            return "Required bundle directory is missing at \(url.path)"
        }
    }
}

public struct BundleLayout: Sendable {
    public static let requiredDirectories = [
        "candidates",
        "selected",
        "output",
        "logs",
        "qc",
        "provenance",
        "previews"
    ]

    public var rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public var manifestURL: URL {
        rootURL.appendingPathComponent("manifest.json")
    }

    public func url(for relativePath: String) -> URL {
        rootURL.appendingPathComponent(relativePath)
    }

    public func createDirectories(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        for directory in Self.requiredDirectories {
            try fileManager.createDirectory(at: rootURL.appendingPathComponent(directory), withIntermediateDirectories: true)
        }
    }

    public func validateStructure(fileManager: FileManager = .default) throws {
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw BundleLayoutError.manifestMissing(manifestURL)
        }

        for directory in Self.requiredDirectories {
            var isDirectory: ObjCBool = false
            let url = rootURL.appendingPathComponent(directory)
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw BundleLayoutError.requiredDirectoryMissing(url)
            }
        }
    }
}

public enum BundleManifestFactory {
    public static func capturedBaseline(
        jobId: String,
        prompt: String,
        imagePath: String,
        createdAt: Date = Date()
    ) -> BundleManifest {
        let candidate = StillCandidate(
            index: 0,
            backend: "captured",
            imagePath: imagePath,
            thumbnailPath: imagePath
        )
        let artifacts = ArtifactLayout(
            candidates: [imagePath],
            selected: imagePath,
            output: [],
            logs: [],
            qc: [],
            provenance: []
        )
        return BundleManifest(
            jobId: jobId,
            status: .candidateSelected,
            prompt: prompt,
            createdAt: createdAt,
            stillCandidates: [candidate],
            selectedStill: SelectedStill(
                index: 0,
                backend: "captured",
                imagePath: imagePath,
                qcReport: QCReport(checks: [])
            ),
            artifacts: artifacts,
            provenance: ProvenanceRecord(stillGeneration: StillGenerationProvenance(backend: "captured"))
        )
    }
}
