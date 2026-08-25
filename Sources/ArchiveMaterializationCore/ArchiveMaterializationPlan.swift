/// How a catalog-selected archive entry must be materialized before playback.
/// The plan is UI-neutral; the archive engine owns the format-specific
/// extraction, dependency, and cache work for the selected plan.
public enum ArchiveMaterializationPlan: String, Equatable, Sendable {
    case selectedEntry
    case completeSet
    case completeSetWithLazyUSFAliases
}
