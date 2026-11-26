import XCTest
@testable import ZirbeCore

final class NotificationRulesTests: XCTestCase {
    private func item(_ address: String?, _ kinds: Set<MessageKind>, alert: ConversationAlert = .default) -> NewMailItem {
        NewMailItem(accountID: "me@example.com", threadID: "t", senderName: nil, senderAddress: address,
                    subject: "Hello", kinds: kinds, alert: alert)
    }

    func testDefaultsNotifyForEverything() {
        let rules = NotificationRules()
        for kind in MessageKind.allCases {
            XCTAssertTrue(rules.notifies(item(nil, [kind])))
        }
    }

    func testTextFromFavoritesAndAllAudio() {
        let rules = NotificationRules(
            who: [.plainText: .favorites, .formattedText: .favorites],
            favorites: SenderList.adding("family.example", to: "")
        )
        XCTAssertTrue(rules.notifies(item("mom@family.example", [.plainText])))
        XCTAssertFalse(rules.notifies(item("boss@work.example", [.plainText])))
        XCTAssertTrue(rules.notifies(item("boss@work.example", [.plainText, .audio])))
    }

    func testMuteBeatsAFavorite() {
        let rules = NotificationRules(favorites: SenderList.adding("mom@family.example", to: ""))
        XCTAssertFalse(rules.notifies(item("mom@family.example", [.plainText], alert: .mute)))
    }

    func testAlwaysBeatsNobody() {
        let rules = NotificationRules(who: Dictionary(uniqueKeysWithValues: MessageKind.allCases.map { ($0, NotifyWho.nobody) }))
        XCTAssertFalse(rules.notifies(item(nil, [.plainText])))
        XCTAssertTrue(rules.notifies(item(nil, [.plainText], alert: .always)))
    }

    func testMissingAddressIsNotAFavorite() {
        let rules = NotificationRules(who: [.plainText: .favorites], favorites: SenderList.adding("family.example", to: ""))
        XCTAssertFalse(rules.notifies(item(nil, [.plainText])))
    }
}
