import XCTest
@testable import ZirbeCore

final class SubjectNormalizerTests: XCTestCase {
    func testStripsSingleRe() {
        XCTAssertEqual(SubjectNormalizer.normalize("Re: Hello"), "Hello")
    }

    func testStripsRepeatedMixedPrefixes() {
        XCTAssertEqual(SubjectNormalizer.normalize("RE: re: Fwd: Hello"), "Hello")
    }

    func testStripsCounterForm() {
        XCTAssertEqual(SubjectNormalizer.normalize("Re[2]: Hello"), "Hello")
    }

    func testLeavesPlainSubject() {
        XCTAssertEqual(SubjectNormalizer.normalize("Hello"), "Hello")
    }

    func testDoesNotStripInteriorWord() {
        XCTAssertEqual(SubjectNormalizer.normalize("Regarding the report"), "Regarding the report")
    }

    func testEmptyAndNil() {
        XCTAssertEqual(SubjectNormalizer.normalize(nil), "")
        XCTAssertEqual(SubjectNormalizer.normalize("   "), "")
    }

    func testTellsAReplyFromAForward() {
        XCTAssertTrue(SubjectNormalizer.isReply("Re: Lunch"))
        XCTAssertTrue(SubjectNormalizer.isReply("SV: Möte"))
        XCTAssertTrue(SubjectNormalizer.isReply("Antw: Afspraak"))
        XCTAssertTrue(SubjectNormalizer.isReply("RE[2]: Lunch"))
        XCTAssertFalse(SubjectNormalizer.isReply("Fwd: Re: Lunch"))
        XCTAssertFalse(SubjectNormalizer.isReply("Lunch"))
        XCTAssertFalse(SubjectNormalizer.isReply("Review: draft"))
        XCTAssertEqual(SubjectNormalizer.normalize("SV: VS: Möte"), "Möte")
        XCTAssertEqual(SubjectNormalizer.normalize("WG: AW: Termin"), "Termin")
    }
}

