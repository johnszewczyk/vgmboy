import Foundation

public struct UACManSkinPreferences: Codable, Equatable, Sendable {
    public var lightColors: [String: String]
    public var darkColors: [String: String]
    public var interfaceFontSize: Double
    public var tableFontSize: Double
    public var tableSurfaceRadius: Double
    public var tableCellRadius: Double

    public init(
        lightColors: [String: String] = Self.defaultLightColors,
        darkColors: [String: String] = Self.defaultDarkColors,
        interfaceFontSize: Double = 13,
        tableFontSize: Double = 10,
        tableSurfaceRadius: Double = 4,
        tableCellRadius: Double = 0
    ) {
        self.lightColors = lightColors
        self.darkColors = darkColors
        self.interfaceFontSize = interfaceFontSize
        self.tableFontSize = tableFontSize
        self.tableSurfaceRadius = tableSurfaceRadius
        self.tableCellRadius = tableCellRadius
    }

    public static let colorKeys = [
        "bg", "panel", "panel-2", "line", "text", "muted", "soft",
        "accent", "accent-soft", "hover", "selected", "green", "red"
    ]

    public static let defaultLightColors: [String: String] = [
        "bg": "#f1f3f6", "panel": "#ffffff", "panel-2": "#f7f8fa",
        "line": "#e1e5eb", "text": "#202630", "muted": "#78818e",
        "soft": "#a1a8b1", "accent": "#345fdb", "accent-soft": "#edf2ff",
        "hover": "#f1f5fc", "selected": "#e8efff", "green": "#228664",
        "red": "#bd4848"
    ]

    public static let defaultDarkColors: [String: String] = [
        "bg": "#181b20", "panel": "#22262c", "panel-2": "#292e35",
        "line": "#373d46", "text": "#e6e9ee", "muted": "#a0a8b4",
        "soft": "#747d89", "accent": "#89a9ff", "accent-soft": "#303d5c",
        "hover": "#2d333d", "selected": "#303c56", "green": "#64c4a1",
        "red": "#ff8c8c"
    ]

    /// Accepts CSS named colors, 3/6 digit hex with an optional #, and RGB
    /// triplets written as three decimal channels separated by spaces or commas.
    public static func normalizedColorInput(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        if hex.count == 3 || hex.count == 6,
           hex.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) }) {
            let expanded: String
            if hex.count == 3 {
                expanded = hex.map { "\($0)\($0)" }.joined()
            } else {
                expanded = hex
            }
            return "#" + expanded.uppercased()
        }

        let rgbBody: String
        if trimmed.lowercased().hasPrefix("rgb("), trimmed.hasSuffix(")") {
            rgbBody = String(trimmed.dropFirst(4).dropLast())
        } else {
            rgbBody = trimmed
        }
        let channels = rgbBody.split(whereSeparator: { $0.isWhitespace || $0 == "," })
        if channels.count == 3,
           let red = Int(channels[0]), let green = Int(channels[1]), let blue = Int(channels[2]),
           (0...255).contains(red), (0...255).contains(green), (0...255).contains(blue) {
            return String(format: "#%02X%02X%02X", red, green, blue)
        }

        let name = trimmed.lowercased()
        return cssNamedColors.contains(name) ? name : nil
    }

    private static let cssNamedColors: Set<String> = Set(
        """
        aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue blueviolet brown burlywood cadetblue chartreuse chocolate coral cornflowerblue cornsilk crimson cyan darkblue darkcyan darkgoldenrod darkgray darkgreen darkgrey darkkhaki darkmagenta darkolivegreen darkorange darkorchid darkred darksalmon darkseagreen darkslateblue darkslategray darkslategrey darkturquoise darkviolet deeppink deepskyblue dimgray dimgrey dodgerblue firebrick floralwhite forestgreen fuchsia gainsboro ghostwhite gold goldenrod gray green greenyellow grey honeydew hotpink indianred indigo ivory khaki lavender lavenderblush lawngreen lemonchiffon lightblue lightcoral lightcyan lightgoldenrodyellow lightgray lightgreen lightgrey lightpink lightsalmon lightseagreen lightskyblue lightslategray lightslategrey lightsteelblue lightyellow lime limegreen linen magenta maroon mediumaquamarine mediumblue mediumorchid mediumpurple mediumseagreen mediumslateblue mediumspringgreen mediumturquoise mediumvioletred midnightblue mintcream mistyrose moccasin navajowhite navy oldlace olive olivedrab orange orangered orchid palegoldenrod palegreen paleturquoise palevioletred papayawhip peachpuff peru pink plum powderblue purple rebeccapurple red rosybrown royalblue saddlebrown salmon sandybrown seagreen seashell sienna silver skyblue slateblue slategray slategrey snow springgreen steelblue tan teal thistle tomato turquoise violet wheat white whitesmoke yellow yellowgreen transparent currentcolor
        """.split(whereSeparator: \.isWhitespace).map(String.init)
    )
}
