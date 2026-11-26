// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// Senders and domains a setting singles out (trusted image senders,
/// notification favorites), kept as one line per entry so it can live in a
/// single stored setting. An entry with an `@` is one sender's address; one
/// without is a domain, which also covers its subdomains.
public enum SenderList {
    public static func entries(_ stored: String) -> [String] {
        stored.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
    }

    public static func contains(_ stored: String, sender: String?) -> Bool {
        guard let sender = sender?.trimmingCharacters(in: .whitespaces).lowercased(), !sender.isEmpty else {
            return false
        }
        let domain = sender.split(separator: "@").last.map(String.init) ?? ""
        return entries(stored).contains { entry in
            entry.contains("@") ? entry == sender : domain == entry || domain.hasSuffix("." + entry)
        }
    }

    /// Whether `entry` itself is stored, compared the way `adding` and `removing`
    /// normalize it. Unlike `contains`, a domain entry does not cover an address.
    public static func listed(_ entry: String, in stored: String) -> Bool {
        entries(stored).contains(normalized(entry))
    }

    public static func adding(_ entry: String, to stored: String) -> String {
        let entry = normalized(entry)
        guard !entry.isEmpty else { return stored }
        return Array(Set(entries(stored) + [entry])).sorted().joined(separator: "\n")
    }

    public static func removing(_ entry: String, from stored: String) -> String {
        entries(stored).filter { $0 != normalized(entry) }.joined(separator: "\n")
    }

    private static func normalized(_ entry: String) -> String {
        let trimmed = entry.trimmingCharacters(in: .whitespaces)
        return (trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed).lowercased()
    }
}
