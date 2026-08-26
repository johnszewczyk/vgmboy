import Foundation

/// Stable identity for one playable playlist row. This preserves the
/// CocoaSpice `pt1` format while making it available to every frontend.
public enum PlaylistTrackIdentity {
    public static func sourceID(sourcePath: String, archiveEntry: String?) -> String {
        if let archiveEntry {
            return "ps1|a|\(sourcePath.utf16.count)|\(sourcePath)|\(archiveEntry.utf16.count)|\(archiveEntry)"
        }
        return "ps1|f|\(sourcePath.utf16.count)|\(sourcePath)"
    }

    public static func trackID(sourcePath: String, archiveEntry: String?, trackIndex: Int) -> String {
        let index = max(0, trackIndex)
        if let archiveEntry {
            return "pt1|a|\(sourcePath.utf16.count)|\(sourcePath)|\(archiveEntry.utf16.count)|\(archiveEntry)|\(index)"
        }
        return "pt1|f|\(sourcePath.utf16.count)|\(sourcePath)|\(index)"
    }
}
