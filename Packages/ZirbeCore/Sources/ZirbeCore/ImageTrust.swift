// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// The senders and domains whose remote images load without asking, kept as one
/// line per entry so it can live in a single stored setting. An entry with an
/// `@` is one sender's address; one without is a domain, which also covers its
/// subdomains.
public enum ImageTrust {
    public static func entries(_ stored: String) -> [String] {
        stored.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
    }

    public static func trusts(_ stored: String, sender: String?) -> Bool {
        guard let sender = sender?.trimmingCharacters(in: .whitespaces).lowercased(), !sender.isEmpty else {
            return false
        }
        let domain = sender.split(separator: "@").last.map(String.init) ?? ""
        return entries(stored).contains { entry in
            entry.contains("@") ? entry == sender : domain == entry || domain.hasSuffix("." + entry)
        }
    }

    public static func adding(_ entry: String, to stored: String) -> String {
        let entry = entry.trimmingCharacters(in: .whitespaces).lowercased()
        guard !entry.isEmpty else { return stored }
        return Array(Set(entries(stored) + [entry])).sorted().joined(separator: "\n")
    }

    public static func removing(_ entry: String, from stored: String) -> String {
        entries(stored).filter { $0 != entry }.joined(separator: "\n")
    }
}
