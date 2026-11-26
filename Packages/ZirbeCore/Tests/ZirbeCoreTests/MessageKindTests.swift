// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The kind classifier against the cases CONVERSATIONS.md § Notifications
// names, and the facts read off an envelope.

import XCTest
import ZirbeMail
@testable import ZirbeCore

final class MessageKindTests: XCTestCase {
    private func part(_ mime: String, _ name: String? = nil) -> KindPart {
        KindPart(mimeType: mime, name: name, embedded: false, size: 1_000, method: nil)
    }

    private func image(embedded: Bool, size: Int) -> KindPart {
        KindPart(mimeType: "image/png", name: nil, embedded: embedded, size: size, method: nil)
    }

    private func calendar(_ method: String?) -> KindPart {
        KindPart(mimeType: "text/calendar", name: nil, embedded: false, size: 1_000, method: method)
    }

    private func sorted(_ kinds: Set<MessageKind>) -> [MessageKind] { kinds.sorted() }

    func testPlainTextMessage() {
        XCTAssertEqual(MessageKind.classify(KindFacts()), [.plainText])
        XCTAssertEqual(MessageKind.classify(KindFacts(html: true)), [.formattedText])
    }

    func testTextWithAVoiceClip() {
        let message = KindFacts(parts: [part("audio/mp4", "voice.m4a")])
        XCTAssertEqual(sorted(MessageKind.classify(message)), [.plainText, .audio])
    }

    func testSignedMailIsOnlyText() {
        let message = KindFacts(parts: [part("application/pgp-signature"), part("application/pkcs7-signature")])
        XCTAssertEqual(MessageKind.classify(message), [.plainText])
    }

    func testSmallEmbeddedImageIsNotAPicture() {
        let message = KindFacts(html: true, parts: [image(embedded: true, size: 8_000)])
        XCTAssertEqual(MessageKind.classify(message), [.formattedText])
    }

    func testLargeEmbeddedImageIsAPicture() {
        let message = KindFacts(html: true, parts: [image(embedded: true, size: 2_000_000)])
        XCTAssertEqual(sorted(MessageKind.classify(message)), [.formattedText, .pictures])
    }

    func testEmbeddedImageAtTheCutoffIsAPicture() {
        let message = KindFacts(html: true, parts: [image(embedded: true, size: 100_000)])
        XCTAssertTrue(MessageKind.classify(message).contains(.pictures))
    }

    func testAttachedImageIsAPictureOfAnySize() {
        let message = KindFacts(parts: [image(embedded: false, size: 8_000)])
        XCTAssertTrue(MessageKind.classify(message).contains(.pictures))
    }

    func testInvitationsAreNotText() {
        XCTAssertEqual(MessageKind.classify(KindFacts(parts: [calendar("REPLY")])), [.invitationReplies])
        XCTAssertEqual(MessageKind.classify(KindFacts(html: true, parts: [calendar("REQUEST")])), [.invitations])
        XCTAssertTrue(MessageKind.classify(KindFacts(parts: [calendar(nil)])).contains(.invitations))
    }

    func testCounterIsAnInvitationReply() {
        XCTAssertEqual(MessageKind.classify(KindFacts(parts: [calendar("COUNTER")])), [.invitationReplies])
    }

    func testGmailInvitationIsOnlyAnInvitation() {
        let message = KindFacts(html: true, parts: [calendar("REQUEST"), part("application/ics", "invite.ics")])
        XCTAssertEqual(MessageKind.classify(message), [.invitations])
    }

    func testLoneIcsFileIsAnInvitation() {
        let message = KindFacts(parts: [part("application/octet-stream", "Meeting.ICS")])
        XCTAssertTrue(MessageKind.classify(message).contains(.invitations))
    }

    func testNewsletterIsNotText() {
        XCTAssertEqual(MessageKind.classify(KindFacts(newsletter: true)), [.newsletters])
        let withPDF = KindFacts(newsletter: true, parts: [part("application/pdf", "issue.pdf")])
        XCTAssertEqual(sorted(MessageKind.classify(withPDF)), [.otherAttachments, .newsletters])
    }

    func testReactionIsOnlyAReaction() {
        XCTAssertEqual(MessageKind.classify(KindFacts(reaction: true)), [.reactions])
    }

    func testNoticeIsExclusive() {
        let message = KindFacts(notice: true, parts: [part("application/pdf", "receipt.pdf")])
        XCTAssertEqual(MessageKind.classify(message), [.notices])
    }

    func testEncryptedIsAnythingElse() {
        let message = KindFacts(encrypted: true, parts: [part("application/octet-stream")])
        XCTAssertEqual(MessageKind.classify(message), [.anythingElse])
    }

    func testEmptyMessageIsAnythingElse() {
        XCTAssertEqual(MessageKind.classify(KindFacts(text: false)), [.anythingElse])
    }

    func testFactsFromAnEnvelope() {
        let body = EnvelopePart(mimeType: "text/plain")
        XCTAssertFalse(MessageKind.facts(of: MailEnvelope(parts: [body])).html)
        XCTAssertTrue(MessageKind.facts(of: MailEnvelope(parts: [EnvelopePart(mimeType: "text/html")])).html)
        XCTAssertFalse(MessageKind.facts(of: MailEnvelope()).text)

        let signed = MailEnvelope(contentType: "application/pkcs7-mime; smime-type=signed-data; name=smime.p7m")
        XCTAssertFalse(MessageKind.facts(of: signed).encrypted)
        let enveloped = MailEnvelope(contentType: "application/pkcs7-mime; smime-type=\"Enveloped-Data\"; name=smime.p7m")
        XCTAssertTrue(MessageKind.facts(of: enveloped).encrypted)
        XCTAssertTrue(MessageKind.facts(of: MailEnvelope(contentType: "application/pkcs7-mime")).encrypted)
        XCTAssertTrue(MessageKind.facts(of: MailEnvelope(contentType: "multipart/encrypted; protocol=x")).encrypted)

        XCTAssertFalse(MessageKind.facts(of: MailEnvelope(autoSubmitted: "no")).notice)
        XCTAssertTrue(MessageKind.facts(of: MailEnvelope(autoSubmitted: "auto-generated")).notice)
        XCTAssertTrue(MessageKind.facts(of: MailEnvelope(contentType: "multipart/report; report-type=delivery-status")).notice)
        XCTAssertTrue(MessageKind.facts(of: MailEnvelope(precedence: "list")).newsletter)
        XCTAssertFalse(MessageKind.facts(of: MailEnvelope(precedence: "junk")).newsletter)
        XCTAssertTrue(MessageKind.facts(of: MailEnvelope(unsubscribe: ["mailto:x@example.com"])).newsletter)
        XCTAssertTrue(MessageKind.facts(of: MailEnvelope(reaction: "👍")).reaction)
    }

    func testFactsFromParts() {
        let envelope = MailEnvelope(parts: [
            EnvelopePart(mimeType: "text/plain"),
            EnvelopePart(mimeType: "text/vnd.google.email-reaction+json"),
            EnvelopePart(mimeType: "image/png", contentID: "<a>", size: 8_000),
            EnvelopePart(mimeType: "text/plain", filename: "notes.txt", disposition: "attachment"),
            EnvelopePart(mimeType: "text/calendar", calendar: "BEGIN:VCALENDAR\r\nMETHOD:reply\r\nEND:VCALENDAR"),
        ])
        let facts = MessageKind.facts(of: envelope)
        XCTAssertEqual(facts.parts.map(\.mimeType), ["image/png", "text/plain", "text/calendar"])
        XCTAssertTrue(facts.parts[0].embedded)
        XCTAssertEqual(facts.parts[0].size, 8_000)
        XCTAssertFalse(facts.parts[1].embedded)
        XCTAssertEqual(facts.parts[2].method, "REPLY")
    }

    func testKindsOrderAsDeclared() {
        XCTAssertLessThan(MessageKind.plainText, .anythingElse)
        XCTAssertEqual(MessageKind.newsletters.label, "Newsletters and lists")
    }
}
