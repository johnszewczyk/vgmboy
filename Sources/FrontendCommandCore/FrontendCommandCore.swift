import Foundation

/// Semantic commands shared by native and WebKit frontend hosts. The host
/// translates these into AppKit menus, Electron accelerators, or web events.
public enum FrontendCommand: String, CaseIterable, Codable, Equatable, Sendable {
    case quit
    case closeWindow
    case minimizeWindow
    case openPath
    case sidebarPaths
    case sidebarConsoles
    case sidebarDiskPath
    case favoritesPlaylist
    case settings
    case previous
    case playPause
    case next
}

/// The persistent catalog views exposed by the native and WebKit skins.
/// Favorites is a playlist projection, not a catalog/sidebar view.
public enum FrontendSidebarView: String, CaseIterable, Codable, Equatable, Sendable {
    case consoles
    case paths

    public var title: String {
        switch self {
        case .consoles: "Console View"
        case .paths: "Path View"
        }
    }
}

public enum FrontendShortcutModifier: String, Codable, CaseIterable, Sendable {
    case command
    case option
    case control
    case shift
}

public struct FrontendShortcut: Codable, Equatable, Sendable {
    public let command: FrontendCommand
    public let key: String
    public let modifiers: Set<FrontendShortcutModifier>

    public init(command: FrontendCommand, key: String, modifiers: Set<FrontendShortcutModifier> = []) {
        self.command = command
        self.key = key
        self.modifiers = modifiers
    }
}

public enum FrontendShortcutCatalog {
    public static let all: [FrontendShortcut] = [
        .init(command: .quit, key: "q", modifiers: [.command]),
        .init(command: .closeWindow, key: "w", modifiers: [.command]),
        .init(command: .minimizeWindow, key: "m", modifiers: [.command]),
        .init(command: .openPath, key: "o", modifiers: [.command]),
        .init(command: .sidebarPaths, key: "1", modifiers: [.command]),
        .init(command: .sidebarConsoles, key: "2", modifiers: [.command]),
        .init(command: .sidebarDiskPath, key: "3", modifiers: [.command]),
        .init(command: .favoritesPlaylist, key: "d", modifiers: [.command, .shift]),
        .init(command: .settings, key: ",", modifiers: [.command]),
        .init(command: .previous, key: "F7"),
        .init(command: .playPause, key: "F8"),
        .init(command: .next, key: "F9")
    ]

    public static func shortcut(for command: FrontendCommand) -> FrontendShortcut {
        guard let shortcut = all.first(where: { $0.command == command }) else {
            preconditionFailure("No shortcut registered for \(command.rawValue)")
        }
        return shortcut
    }
}
