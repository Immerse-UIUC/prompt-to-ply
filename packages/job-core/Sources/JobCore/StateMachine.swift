import Foundation

public enum JobTransitionError: Error, Equatable, CustomStringConvertible {
    case illegalTransition(from: JobStatus, to: JobStatus)

    public var description: String {
        switch self {
        case let .illegalTransition(from, to):
            return "Illegal job status transition from \(from.rawValue) to \(to.rawValue)"
        }
    }
}

public struct JobStateMachine: Sendable {
    private let legalTransitions: [JobStatus: Set<JobStatus>] = [
        .created: [.generatingStills, .generationFailed],
        .generatingStills: [.stillsReady, .generationFailed],
        .stillsReady: [.candidateSelected, .generationFailed],
        .candidateSelected: [.selectedStillQC, .qcFailed],
        .selectedStillQC: [.reconstructionRunning, .qcFailed],
        .reconstructionRunning: [.reconstructionSucceeded, .reconstructionFailed],
        .reconstructionSucceeded: [.bundleWritten, .bundleFailed],
        .bundleWritten: [.viewerReady, .completed, .viewerFailed, .transferFailed],
        .viewerReady: [.completed, .viewerFailed, .transferFailed],
        .completed: [],
        .generationFailed: [],
        .qcFailed: [],
        .reconstructionFailed: [],
        .bundleFailed: [],
        .viewerFailed: [],
        .transferFailed: []
    ]

    public init() {}

    public func canTransition(from: JobStatus, to: JobStatus) -> Bool {
        legalTransitions[from, default: []].contains(to)
    }

    public func transition(_ status: JobStatus, to nextStatus: JobStatus) throws -> JobStatus {
        guard canTransition(from: status, to: nextStatus) else {
            throw JobTransitionError.illegalTransition(from: status, to: nextStatus)
        }
        return nextStatus
    }
}
