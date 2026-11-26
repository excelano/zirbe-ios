// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The pure decision layer for new-mail notifications: given the inbox arrivals a
// background poll found, decide what to post. Kept free of UserNotifications so
// it is platform-agnostic and unit-testable; the app target turns a Plan into
// the actual UNNotificationRequests. The store finds the arrivals (the high-water
// mark in MailStore), this shapes them, the notifier delivers them.

import Foundation

/// One newly arrived inbox message, in the minimal shape a notification needs:
/// who it's from, what it's about, and which conversation to open on a tap. Built
/// from a stored row by `MailStore.unnotifiedInboxArrivals`, so it carries the
/// thread id already stamped by the rethread, not the whole `Message`.
public struct NewMailItem: Sendable, Equatable {
    public let accountID: String
    /// The conversation to open when the notification is tapped. Nil only for the
    /// rare message that never landed in a thread.
    public let threadID: String?
    /// The sender's display name, when the header carried one.
    public let senderName: String?
    /// The sender's address, the fallback label when there's no display name.
    public let senderAddress: String?
    public let subject: String?
    /// What the message is, for the notification rules.
    public let kinds: Set<MessageKind>
    /// The conversation's own alert setting, which overrides the rules.
    public let alert: ConversationAlert
    /// The emoji when the message is a reaction, so the banner reads as one.
    public let reaction: String?

    public init(
        accountID: String, threadID: String?, senderName: String?, senderAddress: String?, subject: String?,
        kinds: Set<MessageKind> = [.anythingElse], alert: ConversationAlert = .default, reaction: String? = nil
    ) {
        self.accountID = accountID
        self.threadID = threadID
        self.senderName = senderName
        self.senderAddress = senderAddress
        self.subject = subject
        self.kinds = kinds
        self.alert = alert
        self.reaction = reaction
    }
}

/// Shapes a batch of new arrivals into a notification plan. A small run posts one
/// banner each (sender and subject); a larger one collapses to a single summary,
/// the way Mail and Messages do, so a busy poll can't fan out into a stack of
/// banners. The cap also bounds any over-count from an edge case to one summary
/// banner rather than a storm.
public enum NewMailNotification {
    /// One banner to post: its title (the sender), its body (the subject), and the
    /// conversation a tap should open.
    public struct Pending: Sendable, Equatable {
        public let accountID: String
        public let threadID: String?
        public let title: String
        public let body: String

        public init(accountID: String, threadID: String?, title: String, body: String) {
            self.accountID = accountID
            self.threadID = threadID
            self.title = title
            self.body = body
        }
    }

    /// What to post: nothing, a banner per message, or one summary for the count.
    public enum Plan: Sendable, Equatable {
        case none
        case items([Pending])
        case summary(count: Int)
    }

    /// The default count above which per-message banners collapse to a summary.
    public static let defaultCap = 3

    /// Decide what to post for the `arrivals` that pass `rules`. None yields
    /// `.none`; up to `cap` of them each get their own banner; more collapse to a
    /// `.summary`.
    public static func plan(for arrivals: [NewMailItem], rules: NotificationRules = NotificationRules(), cap: Int = defaultCap) -> Plan {
        let items = arrivals.filter(rules.notifies)
        guard !items.isEmpty else { return .none }
        guard items.count <= cap else { return .summary(count: items.count) }
        return .items(items.map { item in
            Pending(accountID: item.accountID, threadID: item.threadID, title: senderLabel(item), body: bodyLine(item))
        })
    }

    /// The banner title: the sender's name, then their address, then a neutral
    /// stand-in for the rare message with no usable sender.
    private static func senderLabel(_ item: NewMailItem) -> String {
        if let name = item.senderName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let address = item.senderAddress, !address.isEmpty {
            return address
        }
        return "New message"
    }

    /// The banner body: "Reacted" and the emoji for a reaction, else the subject.
    private static func bodyLine(_ item: NewMailItem) -> String {
        if let emoji = item.reaction, !emoji.isEmpty { return "Reacted \(emoji)" }
        return subjectLine(item)
    }

    /// The subject, or a stand-in for a subjectless message.
    private static func subjectLine(_ item: NewMailItem) -> String {
        let subject = item.subject?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (subject?.isEmpty == false) ? subject! : "(no subject)"
    }
}
