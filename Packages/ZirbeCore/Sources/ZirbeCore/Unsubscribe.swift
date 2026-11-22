// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

/// How to leave a mailing list, from its `List-Unsubscribe` links (RFC 2369).
/// A `mailto:` link is preferred: the request is an ordinary message sent
/// through the user's own server. A web link opens in the browser after the
/// user has seen its site; the app never makes the RFC 8058 one-click request
/// itself, which would contact the list's server directly.
public enum Unsubscribe: Equatable, Sendable {
    case mail(to: String, subject: String, body: String)
    case web(URL)

    public static func request(from links: [String]) -> Unsubscribe? {
        for link in links {
            guard let parts = URLComponents(string: link), parts.scheme?.lowercased() == "mailto" else { continue }
            let to = parts.path.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                .first { $0.contains("@") }
            guard let to else { continue }
            func field(_ name: String) -> String? {
                parts.queryItems?.first { $0.name.lowercased() == name }?.value
                    .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            }
            return .mail(to: to, subject: field("subject") ?? "unsubscribe", body: field("body") ?? "unsubscribe")
        }
        for link in links {
            if let url = URL(string: link), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil {
                return .web(url)
            }
        }
        return nil
    }
}
