import Testing
@testable import FlacPlayerCore

@Test func libFLACLinksAndReportsVersion() {
    #expect(!FLACSanity.libraryVersion.isEmpty)
}
