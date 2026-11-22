// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

public struct LinkCheck: Equatable, Sendable {
    public let address: URL
    public let host: String
    public let warnings: [String]
    public let cleaned: URL?

    static let trackingParameters: Set<String> = [
        "fbclid", "gclid", "dclid", "gbraid", "wbraid", "msclkid", "yclid", "igshid",
        "mc_cid", "mc_eid", "_hsenc", "_hsmi", "mkt_tok", "oly_anon_id", "oly_enc_id", "vero_id",
    ]

    public init?(url: URL, text: String) {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = Self.asciiHost(of: url), !host.isEmpty else { return nil }
        var warnings: [String] = []
        if Self.isNumeric(host) {
            warnings.append("This link goes to a numeric address, \(host), not a named site.")
        }
        if host.split(separator: ".").contains(where: { $0.hasPrefix("xn--") }) {
            let shown = Punycode.unicodeHost(host)
            warnings.append("The site's name is written with international letters: it reads \(shown) but is \(host). Letters that look alike are a common trick.")
        }
        if let named = Self.namedHost(text), !Self.sameSite(named, host) {
            warnings.append("The link reads \(named) but goes to \(host).")
        }
        self.address = url
        self.host = host
        self.warnings = warnings
        self.cleaned = Self.clean(url).flatMap { $0.absoluteString == url.absoluteString ? nil : $0 }
    }

    static func asciiHost(of url: URL) -> String? {
        guard let host = url.host(percentEncoded: false), !host.isEmpty else { return nil }
        guard !host.allSatisfy(\.isASCII) else { return host.lowercased() }
        var components = URLComponents()
        components.host = host
        return components.encodedHost?.lowercased()
    }

    static func isNumeric(_ host: String) -> Bool {
        if host.hasPrefix("[") || host.contains(":") { return true }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        return labels.allSatisfy { label in
            let digits = label.lowercased().hasPrefix("0x") ? label.dropFirst(2) : label[...]
            return !digits.isEmpty && digits.allSatisfy(\.isHexDigit)
                && (label.lowercased().hasPrefix("0x") || digits.allSatisfy(\.isNumber))
        }
    }

    static func namedHost(_ text: String) -> String? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = trimmed.last, ".,;:)".contains(last) { trimmed.removeLast() }
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var host = URL(string: candidate).flatMap(asciiHost(of:)) else { return nil }
        while host.hasSuffix(".") { host.removeLast() }
        guard let dot = host.lastIndex(of: ".") else { return nil }
        let top = host[host.index(after: dot)...]
        let isName = top.count >= 2 && top.allSatisfy { $0.isASCII && $0.isLetter }
        return isName || top.hasPrefix("xn--") ? host : nil
    }

    static func sameSite(_ named: String, _ host: String) -> Bool {
        func bare(_ host: String) -> String {
            let lower = host.lowercased()
            return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
        }
        let (named, host) = (bare(named), bare(host))
        return host == named || host.hasSuffix(".\(named)")
    }

    static func clean(_ url: URL) -> URL? {
        guard let host = url.host(percentEncoded: true)?.lowercased(),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let wrapped: String?
        if host.hasSuffix("safelinks.protection.outlook.com") {
            wrapped = parameter("url", in: components)
        } else if host == "www.google.com", components.path == "/url" {
            wrapped = parameter("q", in: components) ?? parameter("url", in: components)
        } else {
            wrapped = nil
        }
        if let wrapped, let inner = URL(string: wrapped),
           let scheme = inner.scheme?.lowercased(), scheme == "https" || scheme == "http" {
            return clean(inner) ?? inner
        }
        let kept = (components.queryItems ?? []).filter { item in
            let name = item.name.lowercased()
            return !name.hasPrefix("utm_") && !trackingParameters.contains(name)
        }
        components.queryItems = kept.isEmpty ? nil : kept
        return components.url
    }

    static func parameter(_ name: String, in components: URLComponents) -> String? {
        components.queryItems?.first { $0.name == name }?.value
    }
}

enum Punycode {
    static func unicodeHost(_ host: String) -> String {
        host.split(separator: ".", omittingEmptySubsequences: false).map { label in
            label.hasPrefix("xn--") ? decode(String(label.dropFirst(4))) ?? String(label) : String(label)
        }.joined(separator: ".")
    }

    static func decode(_ input: String) -> String? {
        let base = 36, tMin = 1, tMax = 26, skew = 38, damp = 700
        var output: [Unicode.Scalar] = []
        var rest = Substring(input)
        if let delimiter = input.lastIndex(of: "-") {
            output = input[..<delimiter].unicodeScalars.map { $0 }
            rest = input[input.index(after: delimiter)...]
        }
        var n = 128, i = 0, bias = 72
        var digits = rest.makeIterator()
        func adapt(_ delta: Int, _ count: Int, _ first: Bool) -> Int {
            var delta = first ? delta / damp : delta / 2
            delta += delta / count
            var k = 0
            while delta > ((base - tMin) * tMax) / 2 {
                delta /= base - tMin
                k += base
            }
            return k + (base - tMin + 1) * delta / (delta + skew)
        }
        func value(_ c: Character) -> Int? {
            guard let ascii = c.asciiValue else { return nil }
            switch ascii {
            case 48...57: return Int(ascii) - 22
            case 65...90: return Int(ascii) - 65
            case 97...122: return Int(ascii) - 97
            default: return nil
            }
        }
        while true {
            guard let first = digits.next() else { break }
            let oldI = i
            var w = 1, k = base
            var c: Character? = first
            while true {
                guard let current = c, let digit = value(current) else { return nil }
                i += digit * w
                let t = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias)
                if digit < t { break }
                w *= base - t
                k += base
                c = digits.next()
            }
            bias = adapt(i - oldI, output.count + 1, oldI == 0)
            n += i / (output.count + 1)
            i %= output.count + 1
            guard let scalar = Unicode.Scalar(n) else { return nil }
            output.insert(scalar, at: i)
            i += 1
        }
        return String(String.UnicodeScalarView(output))
    }
}
