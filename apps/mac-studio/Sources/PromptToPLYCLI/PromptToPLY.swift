import ArgumentParser
import Foundation
import JobCore

@main
public struct PromptToPLY: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "prompt-to-ply",
        abstract: "Local Prompt-to-PLY Phase 1 control-plane CLI.",
        subcommands: [
            CheckSharpEnv.self,
            RunCaptured.self,
            GenerateCloudStills.self,
            GenerateEquirect.self,
            ExtractViewports.self,
            RunPanoramaViewports.self,
            SelectCandidate.self,
            RunReconstruction.self,
            ValidateBundle.self,
            ShowJob.self
        ]
    )

    public init() {}
}

enum CLIError: Error, CustomStringConvertible {
    case missingPrompt
    case commandNotImplemented(String)
    case missingSelectedStill(String)
    case noPLYOutput(String)

    var description: String {
        switch self {
        case .missingPrompt:
            return "Provide --prompt or --prompt-file."
        case let .commandNotImplemented(command):
            return "\(command) is part of the Phase 1 command surface but is not implemented in this slice."
        case let .missingSelectedStill(bundlePath):
            return "Bundle has no selected still: \(bundlePath)"
        case let .noPLYOutput(outputPath):
            return "SHARP completed but no .ply output was found in \(outputPath)"
        }
    }
}

enum CLIPaths {
    static func fileURL(path: String, isDirectory: Bool = false) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path, isDirectory: isDirectory).standardizedFileURL
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(path, isDirectory: isDirectory)
            .standardizedFileURL
    }

    static func defaultOutputRoot() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return (appSupport ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support"))
            .appendingPathComponent("PromptToPLY")
            .appendingPathComponent("jobs")
    }

    static func repositoryRoot(from currentDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) -> URL {
        var url = currentDirectory
        while url.path != "/" {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("docs/architecture/ARCHITECTURE-v2.md").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return currentDirectory
    }
}

struct PromptOptions: ParsableArguments {
    @Option(help: "Prompt text.")
    var prompt: String?

    @Option(help: "Path to a prompt text file.")
    var promptFile: String?

    func loadPrompt() throws -> String {
        if let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return prompt
        }
        if let promptFile {
            let contents = try String(contentsOfFile: promptFile, encoding: .utf8)
            let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        throw CLIError.missingPrompt
    }
}

struct OutputRootOptions: ParsableArguments {
    @Option(help: "Job output root. Defaults to ~/Library/Application Support/PromptToPLY/jobs.")
    var outputRoot: String?

    func rootURL() -> URL {
        if let outputRoot {
            return CLIPaths.fileURL(path: outputRoot, isDirectory: true)
        }
        return CLIPaths.defaultOutputRoot()
    }
}

enum JSONWriter {
    static func writeEncodable<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = ManifestCodec.makeEncoder()
        let data = try encoder.encode(value)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }
}
