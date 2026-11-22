import XCTest
@testable import ZirbeCore

final class UnsubscribeTests: XCTestCase {
    func testAMailtoLinkIsPreferredAndCarriesItsSubject() {
        let request = Unsubscribe.request(from: [
            "https://example.com/u/42",
            "mailto:leave+news@example.com?subject=Remove%20me",
        ])
        XCTAssertEqual(request, .mail(to: "leave+news@example.com", subject: "Remove me", body: "unsubscribe"))
    }

    func testAWebLinkServesWhenThereIsNoMailto() {
        XCTAssertEqual(Unsubscribe.request(from: ["https://example.com/u/42"]), .web(URL(string: "https://example.com/u/42")!))
    }

    func testNothingUsableGivesNoRequest() {
        XCTAssertNil(Unsubscribe.request(from: []))
        XCTAssertNil(Unsubscribe.request(from: ["mailto:?subject=x", "javascript:go()"]))
    }
}
