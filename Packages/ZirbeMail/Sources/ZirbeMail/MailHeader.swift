// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The Zirbe-specific mail header names. These are wire-protocol details (raw
// RFC 5322 header field names), so they live in the mail layer, shared by the
// send mapping that writes them and the receive mapping that reads them back,
// and referenced by the domain layer that gives them meaning.

/// Zirbe's custom mail headers, carried on messages Zirbe itself composes so a
/// receiving Zirbe can recognize a richer message another client would see only
/// as plain mail.
public enum MailHeader {
    /// Carries a reaction (tapback) emoji on a message that reacts to another.
    /// A receiving Zirbe renders it as a badge on the reacted-to bubble, and so
    /// do earlier versions that predate standard reactions. Header keys arrive
    /// lowercased from the parser, so read incoming values by `lowercased()`.
    public static let zirbeReaction = "X-Zirbe-Reaction"

    /// Marks a reaction's body as one under RFC 9078: on a single-part message
    /// this top-level field is the text part's own disposition, so any client
    /// that supports standard reactions reads the body's emoji as a reaction.
    public static let contentDisposition = "Content-Disposition"
}
