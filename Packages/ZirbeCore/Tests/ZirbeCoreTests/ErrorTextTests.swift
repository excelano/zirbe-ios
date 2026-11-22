// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import XCTest
@testable import ZirbeCore

final class ErrorTextTests: XCTestCase {
    private enum Undescribed: Error { case leftoverDataWhenDone }

    private struct Described: LocalizedError {
        var errorDescription: String? { "The server said no." }
    }

    func testAnErrorWithoutWordsBecomesAPlainSentence() {
        XCTAssertEqual(ErrorText.readable(Undescribed.leftoverDataWhenDone), "Couldn't reach the mail server.")
    }

    func testAnErrorsOwnDescriptionIsKept() {
        XCTAssertEqual(ErrorText.readable(Described()), "The server said no.")
    }

    func testSystemErrorsKeepTheirLocalizedText() {
        let offline = URLError(.notConnectedToInternet)
        XCTAssertEqual(ErrorText.readable(offline), offline.localizedDescription)
        let cocoa = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Disk full."])
        XCTAssertEqual(ErrorText.readable(cocoa), "Disk full.")
    }
}
