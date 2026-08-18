import Foundation

public struct DecoderFamily: Sendable, Codable {
    public var id: String
    public var supportsLongPlay: Bool
    public var supportsTempo: Bool

    public init(id: String, supportsLongPlay: Bool, supportsTempo: Bool) {
        self.id = id
        self.supportsLongPlay = supportsLongPlay
        self.supportsTempo = supportsTempo
    }
}

public enum FormatRegistry {
    public static let libgmeFamily = DecoderFamily(
        id: "libgme",
        supportsLongPlay: true,
        supportsTempo: true
    )

    public static let libvgmFamily = DecoderFamily(
        id: "libvgm",
        supportsLongPlay: true,
        supportsTempo: true
    )

    public static let libgmeExtensions: Set<String> = [
        "ay", "gbs", "hes", "kss", "nsf", "nsfe", "sap", "spc"
    ]

    public static let libvgmExtensions: Set<String> = [
        "vgm", "vgz", "gym", "s98", "dro"
    ]

    public static func family(for path: String) -> DecoderFamily? {
        let ext = (path as NSString).pathExtension.lowercased()
        if libgmeExtensions.contains(ext) {
            return libgmeFamily
        }
        if libvgmExtensions.contains(ext) {
            return libvgmFamily
        }
        return nil
    }
}