/// One logical track published from a source file. `sourceTrackIndex` is the
/// format-native index or slot when the format exposes one; it is not required
/// to be unique because an authored playlist may reference the same source
/// track more than once.
public struct MetadataTrack: Codable, Equatable, Sendable {
    public let sourceTrackIndex: Int?
    public let document: MetadataDocument

    public init(sourceTrackIndex: Int? = nil, document: MetadataDocument) {
        self.sourceTrackIndex = sourceTrackIndex
        self.document = document
    }
}

/// Ordered logical tracks read from one file. `tracks` order is authoritative:
/// readers must preserve authored playlist order and repeated entries rather
/// than sorting or deduplicating by `sourceTrackIndex`.
public struct MetadataReadResult: Codable, Equatable, Sendable {
    public let tracks: [MetadataTrack]
    /// Package-level document for containers whose metadata scopes a set of
    /// member tracks. Nil for ordinary single-file and multi-track formats.
    public let containerDocument: MetadataDocument?

    public init(tracks: [MetadataTrack], containerDocument: MetadataDocument? = nil) {
        self.tracks = tracks
        self.containerDocument = containerDocument
    }
}
