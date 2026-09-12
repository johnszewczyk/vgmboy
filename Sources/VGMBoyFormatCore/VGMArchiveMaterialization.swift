/// The archive preparation required before a catalog-selected member can be
/// handed to VGMBoyKit as an ordinary filesystem path.
///
/// This is a format capability, not a frontend policy. Frontends may own the
/// archive cache and temporary-file lease, but they must ask this contract
/// rather than identifying decoder dependencies themselves.
public enum VGMArchiveMaterializationRequirement: String, Codable, Equatable, Sendable {
    /// The selected member is sufficient on its own.
    case selectedEntry

    /// The complete archive set must be staged beside the selected member.
    case completeSet

    /// The complete set must be staged and `.usflib` members need the
    /// decoder-compatible extensionless aliases used by lazyusf.
    case completeSetWithLazyUSFAliases
}
