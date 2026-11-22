import XCTest
@testable import ZirbeMail

final class MailEnvelopeTests: XCTestCase {
    func testIdentityPrefersUID() {
        let envelope = MailEnvelope(sequenceNumber: 3, uid: 42, messageID: "<a@b>")
        XCTAssertEqual(envelope.id, "uid:42")
    }

    func testIdentityFallsBackToMessageID() {
        let envelope = MailEnvelope(sequenceNumber: 3, messageID: "<a@b>")
        XCTAssertEqual(envelope.id, "mid:<a@b>")
    }

    func testIdentityFallsBackToSequence() {
        let envelope = MailEnvelope(sequenceNumber: 3)
        XCTAssertEqual(envelope.id, "seq:3")
    }

    func testAListsIdentityAndPostingAddressAreRead() {
        let named = MailEnvelope.listIdentity("\"Hiking Club\" <Hiking.Lists.Example.org>")
        XCTAssertEqual(named?.id, "hiking.lists.example.org")
        XCTAssertEqual(named?.name, "Hiking Club")
        XCTAssertEqual(MailEnvelope.listIdentity("<news.example.com>")?.name, "news.example.com")
        XCTAssertNil(MailEnvelope.listIdentity("no brackets here"))

        XCTAssertEqual(MailEnvelope.listPostAddress("<mailto:Hiking@Lists.Example.org?subject=hi>"), "hiking@lists.example.org")
        XCTAssertEqual(MailEnvelope.listPostAddress("<https://example.org/post>, <mailto:post@example.org>"), "post@example.org")
        XCTAssertNil(MailEnvelope.listPostAddress("NO"))
    }

    func testUnsubscribeLinksAreReadInOrderWithFoldingRemoved() {
        XCTAssertEqual(
            MailEnvelope.bracketedLinks("<mailto:leave@example.com>,\r\n <https://example.com/u/\r\n 42>"),
            ["mailto:leave@example.com", "https://example.com/u/42"]
        )
        XCTAssertEqual(MailEnvelope.bracketedLinks(nil), [])
    }
}

