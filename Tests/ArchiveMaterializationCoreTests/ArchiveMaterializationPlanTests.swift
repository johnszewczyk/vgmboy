import ArchiveMaterializationCore
import Testing

@Test
func materializationPlansHaveStableTransportValues() {
    #expect(ArchiveMaterializationPlan.selectedEntry.rawValue == "selectedEntry")
    #expect(ArchiveMaterializationPlan.completeSet.rawValue == "completeSet")
    #expect(ArchiveMaterializationPlan.completeSetWithLazyUSFAliases.rawValue == "completeSetWithLazyUSFAliases")
}
