import XCTest
@testable import ZirbeCore

final class NewMailNotificationTests: XCTestCase {
    private func item(
        thread: String? = "t1",
        name: String? = nil,
        address: String? = "p@x.com",
        subject: String? = "Hello"
    ) -> NewMailItem {
        NewMailItem(accountID: "me@x.com", threadID: thread, senderName: name, senderAddress: address, subject: subject)
    }

    func testEmptyIsNone() {
        XCTAssertEqual(NewMailNotification.plan(for: []), .none)
    }

    func testSingleArrivalIsOneBanner() {
        let plan = NewMailNotification.plan(for: [item(name: "Pat Lee", subject: "Lunch?")])
        XCTAssertEqual(plan, .items([
            NewMailNotification.Pending(accountID: "me@x.com", threadID: "t1", title: "Pat Lee", body: "Lunch?")
        ]))
    }

    func testAReactionBannerSaysReactedInsteadOfQuotingTheSubject() {
        let reaction = NewMailItem(
            accountID: "me@x.com", threadID: "t1", senderName: "Pat Lee", senderAddress: "p@x.com",
            subject: "Re: Lunch?", kinds: [.reactions], reaction: "\u{1F44D}"
        )
        XCTAssertEqual(NewMailNotification.plan(for: [reaction]), .items([
            NewMailNotification.Pending(accountID: "me@x.com", threadID: "t1", title: "Pat Lee", body: "Reacted \u{1F44D}")
        ]))
    }

    func testAtCapIsPerMessage() {
        let items = [
            item(thread: "a", name: "A", subject: "1"),
            item(thread: "b", name: "B", subject: "2"),
            item(thread: "c", name: "C", subject: "3"),
        ]
        guard case let .items(banners) = NewMailNotification.plan(for: items) else {
            return XCTFail("expected per-message banners at the cap")
        }
        XCTAssertEqual(banners.map(\.title), ["A", "B", "C"])
        XCTAssertEqual(banners.map(\.body), ["1", "2", "3"])
    }

    func testOverCapCollapsesToSummary() {
        let items = (1...4).map { item(thread: "t\($0)", subject: "s\($0)") }
        XCTAssertEqual(NewMailNotification.plan(for: items), .summary(count: 4))
    }

    func testNameFallsBackToAddressThenStandIn() {
        let noName = NewMailNotification.plan(for: [item(name: nil, address: "raw@x.com")])
        XCTAssertEqual(noName, .items([
            NewMailNotification.Pending(accountID: "me@x.com", threadID: "t1", title: "raw@x.com", body: "Hello")
        ]))

        let noSender = NewMailNotification.plan(for: [item(name: "  ", address: "")])
        XCTAssertEqual(noSender, .items([
            NewMailNotification.Pending(accountID: "me@x.com", threadID: "t1", title: "New message", body: "Hello")
        ]))
    }

    func testMissingSubjectGetsStandIn() {
        let plan = NewMailNotification.plan(for: [item(name: "Pat", subject: "   ")])
        XCTAssertEqual(plan, .items([
            NewMailNotification.Pending(accountID: "me@x.com", threadID: "t1", title: "Pat", body: "(no subject)")
        ]))
    }

    private func arrivals(_ count: Int, muted: Int) -> [NewMailItem] {
        (0..<count).map { n in
            NewMailItem(accountID: "me@x.com", threadID: "t\(n)", senderName: "S\(n)", senderAddress: "p@x.com",
                        subject: "s\(n)", alert: n < muted ? .mute : .default)
        }
    }

    func testSummaryCountsOnlyMessagesThatPass() {
        guard case let .items(banners) = NewMailNotification.plan(for: arrivals(5, muted: 2), rules: NotificationRules()) else {
            return XCTFail("expected per-message banners for the three that pass")
        }
        XCTAssertEqual(banners.count, 3)
        XCTAssertEqual(NewMailNotification.plan(for: arrivals(6, muted: 1), rules: NotificationRules()), .summary(count: 5))
    }

    func testNothingPassingPlansNone() {
        XCTAssertEqual(NewMailNotification.plan(for: arrivals(3, muted: 3), rules: NotificationRules()), .none)
    }
}
