// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The mailing list a message came through, from its `List-Id` (RFC 2919) and
/// `List-Post` (RFC 2369) headers. Every message of one list forms a single
/// conversation, named for the list (see CONVERSATIONS.md).
public struct MailingList: Sendable, Hashable, Codable {
    /// The list's identifier, lowercased, such as `hiking.lists.example.org`.
    public var id: String
    /// The list's name from the `List-Id` phrase, or its identifier.
    public var name: String
    /// The list's posting address from `List-Post`, lowercased, or nil for a list
    /// that takes no posts (a newsletter).
    public var post: String?

    public init(id: String, name: String, post: String? = nil) {
        self.id = id
        self.name = name
        self.post = post
    }
}
