// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The engine's and sender's pure rules, testable with no connection: the
// transport security each port demands (TLS is required, never opportunistic),
// and the scan for the Content-IDs an HTML body actually paints, so only the
// inline parts the page references ship to the renderer.

import XCTest
import SwiftMail
@testable import ZirbeMail

final class EngineHelperTests: XCTestCase {
    // MARK: Transport security

    func testIMAPRequiresImplicitTLSOn993AndSTARTTLSEverywhereElse() {
        XCTAssertEqual(MailEngine.transportSecurity(port: 993), .implicitTLS)
        XCTAssertEqual(MailEngine.transportSecurity(port: 143), .startTLS)
        XCTAssertEqual(MailEngine.transportSecurity(port: 1143), .startTLS, "a non-standard port never falls to plaintext")
    }

    func testSMTPRequiresImplicitTLSOn465AndSTARTTLSEverywhereElse() {
        XCTAssertEqual(MailSender.transportSecurity(port: 465), .implicitTLS)
        XCTAssertEqual(MailSender.transportSecurity(port: 587), .startTLS)
        XCTAssertEqual(MailSender.transportSecurity(port: 25), .startTLS)
        XCTAssertEqual(MailSender.transportSecurity(port: 2525), .startTLS, "a non-standard port never falls to plaintext")
    }

    // MARK: Send errors

    func testASignInRefusalCarriesTheServersReply() {
        let error = MailSender.readable(SMTPError.authenticationFailed("5.7.8 Username and Password not accepted"))

        XCTAssertEqual(error as? MailSignInRefusal, MailSignInRefusal(reply: "5.7.8 Username and Password not accepted"))
        XCTAssertEqual(error.localizedDescription,
                       "The mail server refused to sign in for sending: 5.7.8 Username and Password not accepted")
    }

    func testMicrosoftsTurnedOffSMTPSaysWhoCanTurnItOn() {
        let reply = "5.7.139 Authentication unsuccessful, SmtpClientAuthentication is disabled for the Tenant. Visit https://aka.ms/smtp_auth"

        let error = MailSender.readable(SMTPError.authenticationFailed(reply))

        XCTAssertEqual(error.localizedDescription,
                       "Your organization has turned off sending mail through SMTP. Its administrator needs to turn on SMTP AUTH.")
    }

    func testAMessageTooLargeIsRefusedOutright() {
        let error = MailSender.readable(SMTPError.messageTooLarge(messageSizeOctets: 31_200_000, maximumMessageSizeOctets: 25_000_000))

        XCTAssertEqual(error as? MailSendError, .tooLarge(size: 31_200_000, limit: 25_000_000))
    }

    // MARK: cid references

    func testReferencedCIDsAreFoundInImagesAndStylesAndNormalized() {
        let html = """
        <img src="cid:Logo@Host"> <img src='cid:<sig@host>'>
        <div style="background:url(cid:bg@host)"></div>
        <p>plain text mentioning CID:Shout@host too</p>
        """

        let ids = MailEngine.referencedCIDs(in: html)

        XCTAssertEqual(ids, ["logo@host", "sig@host", "bg@host", "shout@host"])
    }

    func testReferencedCIDsIsEmptyForABodyWithoutInlineParts() {
        XCTAssertTrue(MailEngine.referencedCIDs(in: "<p>hello</p>").isEmpty)
        XCTAssertTrue(MailEngine.referencedCIDs(in: "").isEmpty)
    }

    func testNormalizeCIDStripsBracketsAndWhitespaceAndLowercases() {
        XCTAssertEqual(MailEngine.normalizeCID("<Logo@Host>"), "logo@host")
        XCTAssertEqual(MailEngine.normalizeCID("  logo@host \t"), "logo@host")
        XCTAssertEqual(MailEngine.normalizeCID("plain"), "plain")
    }

    func testAPartsIDMatchesTheBodysReferenceAfterNormalization() {
        // The typical pairing: the part declares `<id@host>`, the HTML says `cid:id@host`.
        let referenced = MailEngine.referencedCIDs(in: #"<img src="cid:image001@01DA">"#)
        XCTAssertTrue(referenced.contains(MailEngine.normalizeCID("<IMAGE001@01DA>")))
    }

    // MARK: Reactions from other clients

    private func part(_ type: String, disposition: String? = nil, section: String = "1", text: String? = nil) -> MessagePart {
        var part = MessagePart(sectionString: section, contentType: type, disposition: disposition, filename: nil, contentId: nil)
        part.data = text.map { Data($0.utf8) }
        return part
    }

    func testAStandardReactionIsTheFirstPartMarkedReaction() {
        let single = part("text/plain; charset=utf-8", disposition: "reaction")
        XCTAssertEqual(MailEngine.reactionPart(in: [single])?.section, single.section)

        let first = part("text/plain", disposition: "REACTION", section: "1")
        let comment = part("text/plain", section: "2")
        XCTAssertEqual(MailEngine.reactionPart(in: [first, comment])?.section, first.section)

        XCTAssertNil(MailEngine.reactionPart(in: [part("text/plain")]))
        XCTAssertNil(MailEngine.reactionPart(in: [part("text/plain"), part("text/plain", disposition: "reaction", section: "2")]))
        XCTAssertNil(MailEngine.reactionPart(in: [part("text/html", disposition: "reaction")]))
    }

    private func info(_ parts: [MessagePart], replying: Bool = false, seen: Bool = false) -> MessageInfo {
        MessageInfo(
            sequenceNumber: SequenceNumber(1),
            inReplyTo: replying ? MessageID(localPart: "a", domain: "b") : nil,
            flags: seen ? [.seen] : [],
            parts: parts
        )
    }

    func testReactionPartsAreSelectedForRepliesWithNoReactionYet() {
        let reaction = part("text/plain", disposition: "reaction")
        let calendar = part("text/calendar", section: "2")

        let reply = info([reaction], replying: true)
        XCTAssertEqual(MailEngine.reactionParts(in: reply, reaction: nil).map(\.section), [reaction.section])
        XCTAssertTrue(MailEngine.reactionParts(in: reply, reaction: "\u{1F44D}").isEmpty)
        XCTAssertTrue(MailEngine.reactionParts(in: info([reaction]), reaction: nil).isEmpty)
        XCTAssertTrue(MailEngine.reactionParts(in: info([part("text/plain"), calendar], replying: true), reaction: nil).isEmpty)
    }

    func testCalendarPartsAreSelectedOnlyForUnseenMessagesAndSmallParts() {
        func calendar(size: Int?) -> MessagePart {
            MessagePart(sectionString: "2", contentType: "text/calendar; charset=utf-8; method=REQUEST", size: size)
        }
        func unseenSections(size: Int?) -> [String] {
            MailEngine.calendarParts(in: info([part("text/plain"), calendar(size: size)])).map(\.section.description)
        }

        XCTAssertEqual(unseenSections(size: nil), ["2"])
        XCTAssertEqual(unseenSections(size: 1_000), ["2"])
        XCTAssertEqual(unseenSections(size: 262_144), ["2"])
        XCTAssertTrue(unseenSections(size: 262_145).isEmpty)
        XCTAssertTrue(MailEngine.calendarParts(in: info([calendar(size: 1_000)], seen: true)).isEmpty)
        XCTAssertTrue(MailEngine.calendarParts(in: info([part("text/plain")])).isEmpty)
        XCTAssertTrue(MailEngine.calendarParts(in: info([part("text/calendarx", section: "2")])).isEmpty)
    }

    func testAGmailReactionPartIsFoundAnywhere() {
        let gmail = part("text/vnd.google.email-reaction+json", section: "3")
        XCTAssertEqual(MailEngine.reactionPart(in: [part("text/plain"), part("text/html", section: "2"), gmail])?.section, gmail.section)
    }

    func testTheEmojiIsReadFromEitherKindOfPart() {
        XCTAssertEqual(MailEngine.reactionText(of: part("text/plain", disposition: "reaction", text: "\u{1F44D}\r\n")), "\u{1F44D}")
        XCTAssertEqual(MailEngine.reactionText(of: part("text/plain", disposition: "reaction", text: "\r\n")), "")
        let json = #"{"emoji":"\u2764\ufe0f","version":1}"#
        XCTAssertEqual(MailEngine.reactionText(of: part("text/vnd.google.email-reaction+json", text: json)), "\u{2764}\u{FE0F}")
    }
}

