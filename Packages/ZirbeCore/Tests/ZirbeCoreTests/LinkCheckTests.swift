// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import XCTest
@testable import ZirbeCore

final class LinkCheckTests: XCTestCase {
    private func check(_ href: String, _ text: String = "") throws -> LinkCheck {
        try XCTUnwrap(LinkCheck(url: XCTUnwrap(URL(string: href)), text: text))
    }

    func testAnOrdinaryLinkCarriesNoWarning() throws {
        let checked = try check("https://www.example.com/account", "example.com")
        XCTAssertEqual(checked.host, "www.example.com")
        XCTAssertEqual(checked.warnings, [])
        XCTAssertNil(checked.cleaned)
        XCTAssertEqual(try check("https://news.example.com/a", "Read the story").warnings, [])
    }

    func testOnlyWebLinksAreChecked() throws {
        XCTAssertNil(LinkCheck(url: try XCTUnwrap(URL(string: "mailto:pat@example.com")), text: ""))
        XCTAssertNil(LinkCheck(url: try XCTUnwrap(URL(string: "tel:+15551234")), text: ""))
    }

    func testLinkTextNamingAnotherSiteIsFlagged() throws {
        XCTAssertEqual(
            try check("https://login.example.net/", "https://www.mybank.com/login").warnings,
            ["The link reads www.mybank.com but goes to login.example.net."]
        )
        XCTAssertEqual(try check("https://click.mybank.com/x", "mybank.com.").warnings, [])
        XCTAssertEqual(try check("https://example.com/", "here.").warnings, [])
    }

    func testNumericAndInternationalHostsAreFlagged() throws {
        XCTAssertEqual(try check("http://3232235777/login").warnings.count, 1)
        XCTAssertEqual(try check("http://192.168.1.1/login").warnings.count, 1)
        XCTAssertEqual(try check("http://[::1]/login").warnings.count, 1)
        let lookalike = try check("https://xn--pple-43d.com/")
        XCTAssertEqual(lookalike.warnings.count, 1)
        XCTAssertTrue(lookalike.warnings[0].contains("\u{0430}pple.com"), lookalike.warnings[0])
        XCTAssertEqual(try check("https://\u{0430}pple.com/").host, "xn--pple-43d.com")
    }

    func testTrackingIsCleanedAway() throws {
        XCTAssertEqual(
            try check("https://shop.example/item?id=7&utm_source=mail&fbclid=abc").cleaned?.absoluteString,
            "https://shop.example/item?id=7"
        )
        XCTAssertEqual(
            try check("https://eur01.safelinks.protection.outlook.com/?url=https%3A%2F%2Fexample.org%2Fdoc%3Futm_medium%3Demail&data=x").cleaned?.absoluteString,
            "https://example.org/doc"
        )
        XCTAssertEqual(
            try check("https://www.google.com/url?q=https%3A%2F%2Fexample.org%2Fa&sa=D").cleaned?.absoluteString,
            "https://example.org/a"
        )
    }

    func testPunycodeDecodesToTheLettersItHides() {
        XCTAssertEqual(Punycode.unicodeHost("xn--pple-43d.com"), "\u{0430}pple.com")
        XCTAssertEqual(Punycode.unicodeHost("xn--mnchen-3ya.de"), "münchen.de")
        XCTAssertEqual(Punycode.unicodeHost("example.com"), "example.com")
    }
}
