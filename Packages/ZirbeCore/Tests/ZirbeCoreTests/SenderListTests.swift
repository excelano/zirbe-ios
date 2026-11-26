import XCTest
@testable import ZirbeCore

final class SenderListTests: XCTestCase {
    func testContainsASenderOrADomainAndItsSubdomains() {
        var stored = SenderList.adding("News@Example.com", to: "")
        stored = SenderList.adding("shop.example.org", to: stored)
        XCTAssertTrue(SenderList.contains(stored, sender: "news@example.com"))
        XCTAssertFalse(SenderList.contains(stored, sender: "other@example.com"))
        XCTAssertTrue(SenderList.contains(stored, sender: "deals@shop.example.org"))
        XCTAssertTrue(SenderList.contains(stored, sender: "a@mail.shop.example.org"))
        XCTAssertFalse(SenderList.contains(stored, sender: "a@example.org"))
        XCTAssertFalse(SenderList.contains(stored, sender: nil))
        XCTAssertEqual(SenderList.entries(SenderList.removing("shop.example.org", from: stored)), ["news@example.com"])
    }

    func testLeadingAtSignNamesADomain() {
        let stored = SenderList.adding(" @Family.example", to: "")
        XCTAssertEqual(stored, "family.example")
        XCTAssertTrue(SenderList.contains(stored, sender: "Mom@family.example"))
        XCTAssertEqual(SenderList.removing("@family.example", from: stored), "")
    }

    func testListedMatchesTheNormalizedEntryOnly() {
        let stored = SenderList.adding("  Mom@Family.Example ", to: "")
        XCTAssertTrue(SenderList.listed("MOM@family.example", in: stored))
        XCTAssertFalse(SenderList.listed("dad@family.example", in: stored))
        XCTAssertFalse(SenderList.listed("mom@family.example", in: SenderList.adding("family.example", to: "")))
    }
}
