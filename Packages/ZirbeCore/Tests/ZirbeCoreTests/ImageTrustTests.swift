import XCTest
@testable import ZirbeCore

final class ImageTrustTests: XCTestCase {
    func testTrustsASenderOrADomainAndItsSubdomains() {
        var stored = ImageTrust.adding("News@Example.com", to: "")
        stored = ImageTrust.adding("shop.example.org", to: stored)
        XCTAssertTrue(ImageTrust.trusts(stored, sender: "news@example.com"))
        XCTAssertFalse(ImageTrust.trusts(stored, sender: "other@example.com"))
        XCTAssertTrue(ImageTrust.trusts(stored, sender: "deals@shop.example.org"))
        XCTAssertTrue(ImageTrust.trusts(stored, sender: "a@mail.shop.example.org"))
        XCTAssertFalse(ImageTrust.trusts(stored, sender: "a@example.org"))
        XCTAssertFalse(ImageTrust.trusts(stored, sender: nil))
        XCTAssertEqual(ImageTrust.entries(ImageTrust.removing("shop.example.org", from: stored)), ["news@example.com"])
    }
}
