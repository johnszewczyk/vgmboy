import FrontendCommandCore
import Testing

@Test func commonMacCommandsHaveOneSharedShortcutDefinition() {
    #expect(FrontendShortcutCatalog.shortcut(for: .quit).key == "q")
    #expect(FrontendShortcutCatalog.shortcut(for: .closeWindow).key == "w")
    #expect(FrontendShortcutCatalog.shortcut(for: .minimizeWindow).key == "m")
    #expect(FrontendShortcutCatalog.shortcut(for: .playPause).key == "F8")
    #expect(Set(FrontendShortcutCatalog.all.map(\.command)).count == FrontendCommand.allCases.count)
}
