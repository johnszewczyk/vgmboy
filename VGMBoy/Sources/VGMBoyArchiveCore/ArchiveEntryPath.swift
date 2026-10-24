/// Shared archive-member path normalization and traversal policy.
///
/// Archive tools report member names using `/`. A backslash is normally a
/// Windows separator, except when BSD tar uses a three-digit octal escape to
/// reversibly display a non-UTF-8 member byte. Preserve that exact distinction
/// so listing and extraction continue to address the same member.
public enum ArchiveEntryPath {
    public static func normalized(_ entryPath: String) -> String {
        entryPath
            .replacingOccurrences(
                of: "\\",
                with: containsTarOctalEscape(entryPath) ? "\\" : "/"
            )
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }

    public static func isSafe(_ entryPath: String) -> Bool {
        !normalized(entryPath)
            .split(separator: "/")
            .contains("..")
    }

    public static func components(_ entryPath: String) -> [String] {
        normalized(entryPath)
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    /// BSD tar treats selected member arguments as patterns. Quote the pattern
    /// metacharacters so a scanned archive path is selected literally.
    public static func tarMemberSelectionPatterns(_ entryPaths: [String]) -> [String] {
        entryPaths.map { entryPath in
            entryPath
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "*", with: "\\*")
                .replacingOccurrences(of: "?", with: "\\?")
                .replacingOccurrences(of: "[", with: "\\[")
        }
    }

    private static func containsTarOctalEscape(_ path: String) -> Bool {
        let bytes = Array(path.utf8)
        guard bytes.count >= 4 else { return false }
        for index in 0...(bytes.count - 4) where bytes[index] == 0x5C {
            if bytes[(index + 1)...(index + 3)].allSatisfy({ (0x30...0x37).contains($0) }) {
                return true
            }
        }
        return false
    }
}
