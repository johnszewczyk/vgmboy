import Foundation
import PlaybackQueueCore

/// Presentation-neutral facts for a queued handoff. An explicit target may
/// belong to a staged queue; otherwise shared adjacent-navigation policy picks it.
public struct PlaybackQueuedSkipDecisionRequest: Codable, Equatable, Sendable {
    public let expectedGeneration: Int?
    public let requestID: String?
    public let targetTrackID: String?
    public let navigation: PlaybackQueueAdjacentRequest?

    public init(expectedGeneration: Int? = nil, requestID: String? = nil, targetTrackID: String? = nil,
                navigation: PlaybackQueueAdjacentRequest? = nil) {
        self.expectedGeneration = expectedGeneration
        self.requestID = requestID
        self.targetTrackID = targetTrackID
        self.navigation = navigation
    }

    private enum CodingKeys: String, CodingKey {
        case expectedGeneration
        case requestID = "requestId"
        case targetTrackID = "targetTrackId"
        case navigation
    }
}
