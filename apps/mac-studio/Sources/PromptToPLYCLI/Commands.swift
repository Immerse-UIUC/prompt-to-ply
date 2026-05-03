import ArgumentParser
import Foundation
import JobCore

public struct CheckSharpEnv: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "check-sharp-env", abstract: "Check local ml-sharp wrapper availability.")

    @Option(help: "Repository root. Defaults to walking upward from the current directory.")
    var repoRoot: String?

    public init() {}

    public func run() throws {
        let root = repoRoot.map { CLIPaths.fileURL(path: $0, isDirectory: true) } ?? CLIPaths.repositoryRoot()
        let wrapper = root.appendingPathComponent("third_party/ml-sharp/run-predict.sh")
        let bootstrap = root.appendingPathComponent("third_party/ml-sharp/bootstrap-macos.sh")
        let version = root.appendingPathComponent("third_party/ml-sharp/VERSION")
        let sharpEnvName = ProcessInfo.processInfo.environment["PROMPT_TO_PLY_SHARP_ENV"] ?? "prompt-to-ply-sharp"

        print("repoRoot=\(root.path)")
        print("runPredictWrapper=\(wrapper.path)")
        print("runPredictWrapperExists=\(FileManager.default.fileExists(atPath: wrapper.path))")
        print("bootstrapScriptExists=\(FileManager.default.fileExists(atPath: bootstrap.path))")
        print("versionPinExists=\(FileManager.default.fileExists(atPath: version.path))")
        if let pin = try? String(contentsOf: version, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !pin.isEmpty {
            print("versionPin=\(pin)")
        }
        print("sharpEnv=\(sharpEnvName)")
        if let mpsAvailable = try? Shell.capture(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["conda", "run", "-n", sharpEnvName, "python", "-c", "import torch; print(torch.backends.mps.is_available())"]
        ).trimmingCharacters(in: .whitespacesAndNewlines), !mpsAvailable.isEmpty {
            print("mpsAvailable=\(mpsAvailable)")
        } else {
            print("mpsAvailable=unknown")
        }
    }
}

public struct RunCaptured: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "run-captured", abstract: "Create a captured-image baseline bundle.")

    @OptionGroup var promptOptions: PromptOptions
    @OptionGroup var outputOptions: OutputRootOptions

    @Option(help: "Captured input image path.")
    var inputImage: String

    @Option(help: "Optional stable job id. Defaults to a UUID.")
    var jobId: String?

    public init() {}

    public func run() throws {
        let prompt = try promptOptions.loadPrompt()
        let resolvedJobId = jobId ?? UUID().uuidString
        let bundleRoot = outputOptions.rootURL().appendingPathComponent(resolvedJobId, isDirectory: true)
        let layout = BundleLayout(rootURL: bundleRoot)
        try layout.createDirectories()

        let inputURL = CLIPaths.fileURL(path: inputImage)
        let ext = inputURL.pathExtension.isEmpty ? "png" : inputURL.pathExtension
        let candidateRelativePath = "candidates/candidate-000.\(ext)"
        let selectedRelativePath = "selected/selected.\(ext)"
        let candidateURL = layout.url(for: candidateRelativePath)
        let selectedURL = layout.url(for: selectedRelativePath)

        try FileManager.default.copyReplacingItem(at: inputURL, to: candidateURL)
        try FileManager.default.copyReplacingItem(at: inputURL, to: selectedURL)

        let imageReport = ImageValidator.validate(url: selectedURL)
        let imageQCPath = "qc/image-qc.json"
        try JSONWriter.writeEncodable(imageReport, to: layout.url(for: imageQCPath))

        let contactSheetPath = "previews/candidates-contact-sheet.png"
        try? ContactSheetWriter.write(imageURLs: [candidateURL], outputURL: layout.url(for: contactSheetPath), columns: 1)

        let qcReport = QCReport(
            passed: imageReport.validation.passed,
            checks: imageReport.validation.checks.map { QCCheck(name: $0.name, passed: $0.passed, detail: $0.detail) }
        )

        let manifest = BundleManifest(
            jobId: resolvedJobId,
            status: imageReport.validation.passed ? .candidateSelected : .qcFailed,
            prompt: prompt,
            createdAt: Date(),
            updatedAt: Date(),
            stillCandidates: [
                StillCandidate(index: 0, backend: "captured", imagePath: candidateRelativePath, thumbnailPath: candidateRelativePath, qcReport: qcReport)
            ],
            selectedStill: SelectedStill(index: 0, backend: "captured", imagePath: selectedRelativePath, qcReport: qcReport),
            artifacts: ArtifactLayout(
                candidates: [candidateRelativePath],
                selected: selectedRelativePath,
                output: [],
                logs: [],
                qc: [imageQCPath],
                provenance: []
            ),
            provenance: ProvenanceRecord(stillGeneration: StillGenerationProvenance(backend: "captured"))
        )

        try ManifestCodec.write(manifest, to: layout.manifestURL)
        print(bundleRoot.path)
    }
}

public struct ValidateBundle: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "validate-bundle", abstract: "Validate bundle layout, manifest shape, and local artifacts.")

    @Argument(help: "Path to a job bundle.")
    var bundlePath: String

    public init() {}

    public func run() throws {
        let bundleURL = CLIPaths.fileURL(path: bundlePath, isDirectory: true)
        let layout = BundleLayout(rootURL: bundleURL)
        try layout.validateStructure()
        let manifest = try ManifestCodec.read(from: layout.manifestURL)

        var reports: [ValidationReport] = []
        for candidate in manifest.stillCandidates {
            reports.append(ImageValidator.validate(url: layout.url(for: candidate.imagePath)).validation)
        }
        if let selectedStill = manifest.selectedStill {
            reports.append(ImageValidator.validate(url: layout.url(for: selectedStill.imagePath)).validation)
        }
        if let sharpResult = manifest.sharpResult {
            reports.append(PLYValidator.validate(url: layout.url(for: sharpResult.plyPath)).validation)
        }

        let blockingPass = reports.allSatisfy(\.passed)
        print("manifestStatus=\(manifest.status.rawValue)")
        print("artifactReports=\(reports.count)")
        print("passed=\(blockingPass)")

        if !blockingPass {
            throw ExitCode.failure
        }
    }
}

public struct ShowJob: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "show-job", abstract: "Print manifest-driven job state.")

    @Argument(help: "Path to a job bundle.")
    var bundlePath: String

    public init() {}

    public func run() throws {
        let manifestURL = CLIPaths.fileURL(path: bundlePath, isDirectory: true).appendingPathComponent("manifest.json")
        let manifest = try ManifestCodec.read(from: manifestURL)
        print("jobId=\(manifest.jobId)")
        print("status=\(manifest.status.rawValue)")
        print("prompt=\(manifest.prompt)")
        print("candidates=\(manifest.stillCandidates.count)")
        print("selectedIndex=\(manifest.selectedStill?.index.description ?? "none")")
        print("sharpResult=\(manifest.sharpResult?.plyPath ?? "none")")
    }
}

public struct GenerateCloudStills: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "generate-cloud-stills", abstract: "Generate still candidates with a cloud provider.")

    @Option(help: "Provider: openai or gemini.")
    var provider: String = "openai"

    public init() {}

    public func run() throws {
        throw CLIError.commandNotImplemented("generate-cloud-stills --provider \(provider)")
    }
}

public struct GenerateEquirect: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "generate-equirect", abstract: "Generate an equirectangular panorama source.")
    public init() {}
    public func run() throws { throw CLIError.commandNotImplemented("generate-equirect") }
}

public struct ExtractViewports: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "extract-viewports", abstract: "Extract perspective viewports from an equirectangular source.")
    public init() {}
    public func run() throws { throw CLIError.commandNotImplemented("extract-viewports") }
}

public struct RunPanoramaViewports: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "run-panorama-viewports", abstract: "Run SHARP per extracted viewport.")
    public init() {}
    public func run() throws { throw CLIError.commandNotImplemented("run-panorama-viewports") }
}

public struct SelectCandidate: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "select-candidate", abstract: "Select one still candidate by index.")
    public init() {}
    public func run() throws { throw CLIError.commandNotImplemented("select-candidate") }
}

public struct RunReconstruction: ParsableCommand {
    public static let configuration = CommandConfiguration(commandName: "run-reconstruction", abstract: "Run selected-still QC and SHARP reconstruction.")

    @Argument(help: "Path to a job bundle.")
    var bundlePath: String

    @Option(help: "Repository root. Defaults to walking upward from the current directory.")
    var repoRoot: String?

    @Option(help: "Optional path to the run-predict.sh wrapper.")
    var sharpWrapper: String?

    public init() {}

    public func run() throws {
        let bundleURL = CLIPaths.fileURL(path: bundlePath, isDirectory: true)
        let layout = BundleLayout(rootURL: bundleURL)
        try layout.validateStructure()

        var manifest = try ManifestCodec.read(from: layout.manifestURL)
        guard let selectedStill = manifest.selectedStill else {
            throw CLIError.missingSelectedStill(bundleURL.path)
        }

        let inputURL = layout.url(for: selectedStill.imagePath)
        let imageReport = ImageValidator.validate(url: inputURL)
        let imageQCPath = "qc/selected-still-qc.json"
        try JSONWriter.writeEncodable(imageReport, to: layout.url(for: imageQCPath))

        guard imageReport.validation.passed else {
            manifest.status = .qcFailed
            manifest.updatedAt = Date()
            manifest.artifacts.qc.appendIfMissing(imageQCPath)
            try ManifestCodec.write(manifest, to: layout.manifestURL)
            throw ExitCode.failure
        }

        let root = repoRoot.map { CLIPaths.fileURL(path: $0, isDirectory: true) } ?? CLIPaths.repositoryRoot()
        let wrapperURL = sharpWrapper.map { CLIPaths.fileURL(path: $0) } ?? root.appendingPathComponent("third_party/ml-sharp/run-predict.sh")
        let outputRelativePath = "output"
        let outputURL = layout.url(for: outputRelativePath)
        let logRelativePath = "logs/ml-sharp.log"
        let logURL = layout.url(for: logRelativePath)

        manifest.status = .reconstructionRunning
        manifest.updatedAt = Date()
        manifest.artifacts.qc.appendIfMissing(imageQCPath)
        manifest.artifacts.logs.appendIfMissing(logRelativePath)
        try ManifestCodec.write(manifest, to: layout.manifestURL)

        do {
            try Shell.run(executable: wrapperURL, arguments: [inputURL.path, outputURL.path, logURL.path])
        } catch {
            manifest.status = .reconstructionFailed
            manifest.updatedAt = Date()
            try ManifestCodec.write(manifest, to: layout.manifestURL)
            throw error
        }

        guard let plyURL = try FileManager.default.firstPLYFile(in: outputURL) else {
            manifest.status = .reconstructionFailed
            manifest.updatedAt = Date()
            try ManifestCodec.write(manifest, to: layout.manifestURL)
            throw CLIError.noPLYOutput(outputURL.path)
        }

        let plyRelativePath = outputRelativePath + "/" + plyURL.lastPathComponent
        let plyReport = PLYValidator.validate(url: plyURL)
        let plyQCPath = "qc/ply-qc.json"
        try JSONWriter.writeEncodable(plyReport, to: layout.url(for: plyQCPath))

        manifest.status = plyReport.validation.passed ? .bundleWritten : .reconstructionFailed
        manifest.updatedAt = Date()
        manifest.sharpResult = SharpResult(plyPath: plyRelativePath, logPath: logRelativePath, durationMs: 0)
        manifest.artifacts.output.appendIfMissing(plyRelativePath)
        manifest.artifacts.qc.appendIfMissing(plyQCPath)
        manifest.artifacts.logs.appendIfMissing(logRelativePath)
        manifest.provenance.reconstruction.previewImageGenerated = false
        manifest.provenance.reconstruction.previewVideoGenerated = false
        try ManifestCodec.write(manifest, to: layout.manifestURL)

        print("status=\(manifest.status.rawValue)")
        print("ply=\(plyRelativePath)")
    }
}

private extension FileManager {
    func copyReplacingItem(at source: URL, to destination: URL) throws {
        try createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileExists(atPath: destination.path) {
            try removeItem(at: destination)
        }
        try copyItem(at: source, to: destination)
    }

    func firstPLYFile(in directory: URL) throws -> URL? {
        guard fileExists(atPath: directory.path) else {
            return nil
        }
        let contents = try contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return contents
            .filter { $0.pathExtension.lowercased() == "ply" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first
    }
}

private extension Array where Element: Equatable {
    mutating func appendIfMissing(_ element: Element) {
        if !contains(element) {
            append(element)
        }
    }
}

enum Shell {
    static func run(executable: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ExitCode(process.terminationStatus)
        }
    }

    static func capture(executable: URL, arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ExitCode(process.terminationStatus)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
}
