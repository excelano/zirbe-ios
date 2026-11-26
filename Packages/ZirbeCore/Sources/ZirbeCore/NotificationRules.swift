// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Which new messages notify. zirbe-desktop's CONVERSATIONS.md § Notifications
// defines the rules.

import Foundation

public enum NotifyWho: String, CaseIterable, Sendable {
    case everyone, favorites, nobody

    public var label: String {
        switch self {
        case .everyone: "Everyone"
        case .favorites: "Favorites"
        case .nobody: "Nobody"
        }
    }
}

public enum ConversationAlert: String, CaseIterable, Sendable {
    case `default`, always, mute

    public var label: String {
        switch self {
        case .default: "Default"
        case .always: "Always Notify"
        case .mute: "Mute"
        }
    }
}

public struct NotificationRules: Sendable, Equatable {
    /// Who may notify per kind; a kind that is absent notifies for everyone.
    public var who: [MessageKind: NotifyWho]
    public var favorites: String

    public init(who: [MessageKind: NotifyWho] = [:], favorites: String = "") {
        self.who = who
        self.favorites = favorites
    }

    public func who(_ kind: MessageKind) -> NotifyWho {
        who[kind] ?? .everyone
    }

    /// A message notifies when any of its kinds allows its sender; the
    /// conversation's alert overrides that either way.
    public func notifies(_ item: NewMailItem) -> Bool {
        switch item.alert {
        case .mute: false
        case .always: true
        case .default:
            item.kinds.contains { kind in
                switch who(kind) {
                case .everyone: true
                case .favorites: item.senderAddress.map { SenderList.contains(favorites, sender: $0) } ?? false
                case .nobody: false
                }
            }
        }
    }
}
