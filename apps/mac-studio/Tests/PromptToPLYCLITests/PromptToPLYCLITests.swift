import ArgumentParser
import Testing
@testable import PromptToPLYCLI

@Test func rootCommandParsesShowJob() throws {
    let command = try PromptToPLY.parseAsRoot(["show-job", "/tmp/job"])
    #expect(command is ShowJob)
}

@Test func rootCommandParsesRunCaptured() throws {
    let command = try PromptToPLY.parseAsRoot([
        "run-captured",
        "--prompt", "a tiny chair",
        "--input-image", "/tmp/input.png",
        "--output-root", "/tmp/jobs"
    ])
    #expect(command is RunCaptured)
}

@Test func cloudProviderOverrideParses() throws {
    let command = try PromptToPLY.parseAsRoot(["generate-cloud-stills", "--provider", "gemini"])
    #expect(command is GenerateCloudStills)
}

@Test func runReconstructionParses() throws {
    let command = try PromptToPLY.parseAsRoot(["run-reconstruction", "/tmp/job", "--sharp-wrapper", "/tmp/run-predict.sh"])
    #expect(command is RunReconstruction)
}
