import Foundation

public enum JobStatus: String, Codable, CaseIterable, Sendable {
    case created
    case generatingStills = "generating_stills"
    case stillsReady = "stills_ready"
    case candidateSelected = "candidate_selected"
    case selectedStillQC = "selected_still_qc"
    case reconstructionRunning = "reconstruction_running"
    case reconstructionSucceeded = "reconstruction_succeeded"
    case bundleWritten = "bundle_written"
    case viewerReady = "viewer_ready"
    case completed
    case generationFailed = "generation_failed"
    case qcFailed = "qc_failed"
    case reconstructionFailed = "reconstruction_failed"
    case bundleFailed = "bundle_failed"
    case viewerFailed = "viewer_failed"
    case transferFailed = "transfer_failed"

    public var isTerminalFailure: Bool {
        switch self {
        case .generationFailed, .qcFailed, .reconstructionFailed, .bundleFailed, .viewerFailed, .transferFailed:
            return true
        default:
            return false
        }
    }
}

public struct PromptInput: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable {
        case argument
        case file
        case appUI = "app_ui"
        case externalService = "external_service"
    }

    public var originalPrompt: String
    public var refinedPrompt: String?
    public var source: Source
    public var metadata: [String: String]

    public init(originalPrompt: String, refinedPrompt: String? = nil, source: Source, metadata: [String: String] = [:]) {
        self.originalPrompt = originalPrompt
        self.refinedPrompt = refinedPrompt
        self.source = source
        self.metadata = metadata
    }
}

public struct GenerationJob: Codable, Equatable, Sendable {
    public var id: String
    public var prompt: String
    public var inputSource: String
    public var stillBackend: String
    public var status: JobStatus
    public var selectedCandidateIndex: Int?
    public var artifacts: ArtifactLayout
    public var provenance: ProvenanceRecord

    public init(
        id: String,
        prompt: String,
        inputSource: String,
        stillBackend: String,
        status: JobStatus = .created,
        selectedCandidateIndex: Int? = nil,
        artifacts: ArtifactLayout = .canonical(),
        provenance: ProvenanceRecord
    ) {
        self.id = id
        self.prompt = prompt
        self.inputSource = inputSource
        self.stillBackend = stillBackend
        self.status = status
        self.selectedCandidateIndex = selectedCandidateIndex
        self.artifacts = artifacts
        self.provenance = provenance
    }
}

public struct QCCheck: Codable, Equatable, Sendable {
    public var name: String
    public var passed: Bool
    public var detail: String?

    public init(name: String, passed: Bool, detail: String? = nil) {
        self.name = name
        self.passed = passed
        self.detail = detail
    }
}

public struct QCReport: Codable, Equatable, Sendable {
    public var passed: Bool
    public var checks: [QCCheck]

    public init(checks: [QCCheck]) {
        self.checks = checks
        self.passed = checks.allSatisfy(\.passed)
    }

    public init(passed: Bool, checks: [QCCheck]) {
        self.passed = passed
        self.checks = checks
    }
}

public struct StillCandidate: Codable, Equatable, Sendable {
    public var index: Int
    public var seed: Int?
    public var backend: String
    public var imagePath: String
    public var thumbnailPath: String
    public var qcReport: QCReport?

    public init(index: Int, seed: Int? = nil, backend: String, imagePath: String, thumbnailPath: String, qcReport: QCReport? = nil) {
        self.index = index
        self.seed = seed
        self.backend = backend
        self.imagePath = imagePath
        self.thumbnailPath = thumbnailPath
        self.qcReport = qcReport
    }
}

public struct SelectedStill: Codable, Equatable, Sendable {
    public var index: Int
    public var seed: Int?
    public var backend: String
    public var imagePath: String
    public var qcReport: QCReport

    public init(index: Int, seed: Int? = nil, backend: String, imagePath: String, qcReport: QCReport) {
        self.index = index
        self.seed = seed
        self.backend = backend
        self.imagePath = imagePath
        self.qcReport = qcReport
    }
}

public struct SharpResult: Codable, Equatable, Sendable {
    public var plyPath: String
    public var previewImagePath: String?
    public var previewVideoPath: String?
    public var logPath: String
    public var durationMs: Int

    public init(plyPath: String, previewImagePath: String? = nil, previewVideoPath: String? = nil, logPath: String, durationMs: Int) {
        self.plyPath = plyPath
        self.previewImagePath = previewImagePath
        self.previewVideoPath = previewVideoPath
        self.logPath = logPath
        self.durationMs = durationMs
    }
}

public struct ArtifactLayout: Codable, Equatable, Sendable {
    public var candidates: [String]
    public var selected: String?
    public var output: [String]
    public var logs: [String]
    public var qc: [String]
    public var provenance: [String]

    public init(candidates: [String], selected: String?, output: [String], logs: [String], qc: [String], provenance: [String]) {
        self.candidates = candidates
        self.selected = selected
        self.output = output
        self.logs = logs
        self.qc = qc
        self.provenance = provenance
    }

    public static func canonical() -> ArtifactLayout {
        ArtifactLayout(candidates: [], selected: nil, output: [], logs: [], qc: [], provenance: [])
    }
}

public struct StillGenerationProvenance: Codable, Equatable, Sendable {
    public var backend: String
    public var seed: Int?

    public init(backend: String, seed: Int? = nil) {
        self.backend = backend
        self.seed = seed
    }
}

public struct ReconstructionProvenance: Codable, Equatable, Sendable {
    public var backend: String
    public var previewImageGenerated: Bool?
    public var previewVideoGenerated: Bool?

    public init(backend: String = "ml-sharp", previewImageGenerated: Bool? = nil, previewVideoGenerated: Bool? = nil) {
        self.backend = backend
        self.previewImageGenerated = previewImageGenerated
        self.previewVideoGenerated = previewVideoGenerated
    }
}

public struct CameraModelProvenance: Codable, Equatable, Sendable {
    public var mode: String
    public var focalLength: String

    public init(mode: String = "assumed", focalLength: String = "30mm_default") {
        self.mode = mode
        self.focalLength = focalLength
    }
}

public struct ProvenanceRecord: Codable, Equatable, Sendable {
    public var stillGeneration: StillGenerationProvenance
    public var reconstruction: ReconstructionProvenance
    public var cameraModel: CameraModelProvenance

    public init(
        stillGeneration: StillGenerationProvenance,
        reconstruction: ReconstructionProvenance = ReconstructionProvenance(),
        cameraModel: CameraModelProvenance = CameraModelProvenance()
    ) {
        self.stillGeneration = stillGeneration
        self.reconstruction = reconstruction
        self.cameraModel = cameraModel
    }
}

public struct BundleManifest: Codable, Equatable, Sendable {
    public var bundleVersion: String
    public var jobId: String
    public var status: JobStatus
    public var prompt: String
    public var createdAt: Date
    public var updatedAt: Date?
    public var viewerCompatibilityVersion: String?
    public var stillCandidates: [StillCandidate]
    public var selectedStill: SelectedStill?
    public var sharpResult: SharpResult?
    public var artifacts: ArtifactLayout
    public var provenance: ProvenanceRecord

    public init(
        bundleVersion: String = "0.1.0",
        jobId: String,
        status: JobStatus,
        prompt: String,
        createdAt: Date,
        updatedAt: Date? = nil,
        viewerCompatibilityVersion: String? = nil,
        stillCandidates: [StillCandidate] = [],
        selectedStill: SelectedStill? = nil,
        sharpResult: SharpResult? = nil,
        artifacts: ArtifactLayout = .canonical(),
        provenance: ProvenanceRecord
    ) {
        self.bundleVersion = bundleVersion
        self.jobId = jobId
        self.status = status
        self.prompt = prompt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.viewerCompatibilityVersion = viewerCompatibilityVersion
        self.stillCandidates = stillCandidates
        self.selectedStill = selectedStill
        self.sharpResult = sharpResult
        self.artifacts = artifacts
        self.provenance = provenance
    }
}

public struct PanoramaInput: Codable, Equatable, Sendable {
    public var sourceImagePath: String
    public var projection: String
    public var qcReport: QCReport?

    public init(sourceImagePath: String, projection: String = "equirectangular", qcReport: QCReport? = nil) {
        self.sourceImagePath = sourceImagePath
        self.projection = projection
        self.qcReport = qcReport
    }
}

public struct PerspectiveViewport: Codable, Equatable, Sendable {
    public var id: String
    public var yaw: Int
    public var pitch: Int
    public var fieldOfView: Int
    public var imagePath: String
    public var qcReport: QCReport?

    public init(id: String, yaw: Int, pitch: Int, fieldOfView: Int, imagePath: String, qcReport: QCReport? = nil) {
        self.id = id
        self.yaw = yaw
        self.pitch = pitch
        self.fieldOfView = fieldOfView
        self.imagePath = imagePath
        self.qcReport = qcReport
    }
}

public struct ViewportSet: Codable, Equatable, Sendable {
    public var source: PanoramaInput
    public var viewports: [PerspectiveViewport]
    public var extractionReportPath: String?

    public init(source: PanoramaInput, viewports: [PerspectiveViewport], extractionReportPath: String? = nil) {
        self.source = source
        self.viewports = viewports
        self.extractionReportPath = extractionReportPath
    }
}

public struct ViewportSharpResult: Codable, Equatable, Sendable {
    public var viewportId: String
    public var sharpResult: SharpResult

    public init(viewportId: String, sharpResult: SharpResult) {
        self.viewportId = viewportId
        self.sharpResult = sharpResult
    }
}

public struct PanoramaRunManifest: Codable, Equatable, Sendable {
    public var jobId: String
    public var prompt: String
    public var panoramaInput: PanoramaInput
    public var viewportSet: ViewportSet
    public var sharpResults: [ViewportSharpResult]
    public var provenance: ProvenanceRecord
    public var viewerCompatibilityVersion: String?

    public init(
        jobId: String,
        prompt: String,
        panoramaInput: PanoramaInput,
        viewportSet: ViewportSet,
        sharpResults: [ViewportSharpResult],
        provenance: ProvenanceRecord,
        viewerCompatibilityVersion: String? = nil
    ) {
        self.jobId = jobId
        self.prompt = prompt
        self.panoramaInput = panoramaInput
        self.viewportSet = viewportSet
        self.sharpResults = sharpResults
        self.provenance = provenance
        self.viewerCompatibilityVersion = viewerCompatibilityVersion
    }
}
