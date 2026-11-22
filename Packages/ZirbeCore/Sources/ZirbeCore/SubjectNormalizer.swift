// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Strips reply/forward prefixes from a subject so a thread shows one clean
// title instead of a creeping pile of "Re: Re: Fwd:". The conversation keeps
// its name; the prefixes are noise.

import Foundation

public enum SubjectNormalizer {
    /// Remove leading reply and forward prefixes (repeated, case-insensitive,
    /// with optional `[n]` counters as some mailers add) and return the trimmed
    /// core subject. An empty or whitespace-only subject normalizes to "".
    public static func normalize(_ subject: String?) -> String {
        prefixes(subject).rest
    }

    /// Whether a subject presents itself as a reply: its first prefix is a reply
    /// prefix (`Re:`, `AW:`, `SV:`, ...), not a forward. A reply that lost its
    /// threading headers is recognized by this.
    public static func isReply(_ subject: String?) -> Bool {
        prefixes(subject).firstIsReply == true
    }

    /// Prefixes that mark a reply, in the languages mail programs commonly use.
    private static let reply = ["antw", "odp", "ynt", "rif", "re", "aw", "sv", "vs"]
    /// Prefixes that mark a forward.
    private static let forward = ["fwd", "fw", "wg"]

    private static func prefixes(_ subject: String?) -> (firstIsReply: Bool?, rest: String) {
        guard var s = subject?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return (nil, "")
        }
        var firstIsReply: Bool?
        // One prefix at the front, an optional [n] counter, a colon, optional space.
        let pattern = "^(" + (forward + reply).joined(separator: "|") + #")(?:\[\d+\])?:\s*"#
        while let range = s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            if firstIsReply == nil {
                let word = s[range].prefix { $0.isLetter }.lowercased()
                firstIsReply = reply.contains(word)
            }
            s.removeSubrange(range)
            s = s.trimmingCharacters(in: .whitespaces)
        }
        return (firstIsReply, s)
    }
}
