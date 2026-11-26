// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The kinds a message is, from its parts and headers, that notification rules
// match. zirbe-desktop's CONVERSATIONS.md § Notifications defines the rules.

import Foundation
import ZirbeMail

public enum MessageKind: String, CaseIterable, Sendable, Comparable {
    case plainText, formattedText, pictures, audio, video, otherAttachments,
         invitations, invitationReplies, reactions, newsletters, notices, anythingElse

    public var label: String {
        switch self {
        case .plainText: "Plain text"
        case .formattedText: "Formatted text"
        case .pictures: "Pictures"
        case .audio: "Audio"
        case .video: "Video"
        case .otherAttachments: "Other attachments"
        case .invitations: "Invitations"
        case .invitationReplies: "Invitation replies"
        case .reactions: "Reactions"
        case .newsletters: "Newsletters and lists"
        case .notices: "Automatic notices"
        case .anythingElse: "Anything else"
        }
    }

    public static func < (lhs: MessageKind, rhs: MessageKind) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

struct KindPart {
    var mimeType: String
    var name: String?
    var embedded: Bool
    var size: Int
    var method: String?
}

struct KindFacts {
    var text = true
    var html = false
    var newsletter = false
    var notice = false
    var encrypted = false
    var reaction = false
    var parts: [KindPart] = []
}

extension MessageKind {
    private static let embeddedPictureLimit = 100_000
    private static let signatures: Set<String> = [
        "application/pgp-signature", "application/pkcs7-signature", "application/x-pkcs7-signature",
    ]
    private static let reactionType = "text/vnd.google.email-reaction+json"

    private static func name(_ name: String, endsWithAny extensions: [String]) -> Bool {
        let lower = name.lowercased()
        return extensions.contains { lower.hasSuffix($0) }
    }

    private static func isAudio(_ name: String) -> Bool {
        Self.name(name, endsWithAny: [".m4a", ".mp3", ".aac", ".wav", ".ogg", ".oga", ".opus", ".flac"])
    }

    private static func isVideo(_ name: String) -> Bool {
        Self.name(name, endsWithAny: [".mp4", ".mov", ".m4v", ".webm", ".3gp", ".mkv"])
    }

    private static func isPicture(_ name: String) -> Bool {
        Self.name(name, endsWithAny: [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".heif", ".bmp", ".tiff"])
    }

    private static func kind(of part: KindPart, hasCalendar: Bool) -> MessageKind? {
        let name = part.name ?? ""
        if signatures.contains(part.mimeType) {
            return nil
        } else if part.mimeType == "text/calendar" {
            return part.method == "REPLY" || part.method == "COUNTER" ? .invitationReplies : .invitations
        } else if part.mimeType == "application/ics" || Self.name(name, endsWithAny: [".ics"]) {
            return hasCalendar ? nil : .invitations
        } else if part.mimeType.hasPrefix("image/") || isPicture(name) {
            return part.embedded && part.size < embeddedPictureLimit ? nil : .pictures
        } else if part.mimeType.hasPrefix("audio/") || isAudio(name) {
            return .audio
        } else if part.mimeType.hasPrefix("video/") || isVideo(name) {
            return .video
        }
        return .otherAttachments
    }

    static func classify(_ facts: KindFacts) -> Set<MessageKind> {
        if facts.encrypted { return [.anythingElse] }
        if facts.notice { return [.notices] }
        let hasCalendar = facts.parts.contains { $0.mimeType == "text/calendar" }
        var kinds = Set(facts.parts.compactMap { kind(of: $0, hasCalendar: hasCalendar) })
        if facts.reaction { kinds.insert(.reactions) }
        if facts.newsletter { kinds.insert(.newsletters) }
        if facts.text, !facts.reaction, !facts.newsletter,
           kinds.isDisjoint(with: [.invitations, .invitationReplies]) {
            kinds.insert(facts.html ? .formattedText : .plainText)
        }
        return kinds.isEmpty ? [.anythingElse] : kinds
    }

    static func facts(of envelope: MailEnvelope) -> KindFacts {
        var bodyParts: [EnvelopePart] = []
        var parts: [KindPart] = []
        for part in envelope.parts {
            let isBody = (part.mimeType == "text/plain" || part.mimeType == "text/html")
                && part.disposition != "attachment"
            if isBody {
                bodyParts.append(part)
            } else if part.mimeType != reactionType {
                parts.append(KindPart(
                    mimeType: part.mimeType,
                    name: part.filename,
                    embedded: part.contentID != nil && part.disposition != "attachment",
                    size: part.size ?? 0,
                    method: part.calendar.flatMap { InviteParser.method(iCalendar: $0) }
                ))
            }
        }

        let rootType = envelope.contentType?
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false).first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let isSMIME = rootType == "application/pkcs7-mime" || rootType == "application/x-pkcs7-mime"

        return KindFacts(
            text: !bodyParts.isEmpty,
            html: bodyParts.contains { $0.mimeType == "text/html" },
            newsletter: envelope.listID != nil || !envelope.unsubscribe.isEmpty
                || ["bulk", "list"].contains(envelope.precedence ?? ""),
            notice: rootType == "multipart/report"
                || parts.contains { $0.mimeType == "message/disposition-notification" }
                || envelope.autoSubmitted.map { $0 != "no" } ?? false,
            encrypted: rootType == "multipart/encrypted"
                || (isSMIME && !["signed-data", "certs-only"].contains(smimeType(envelope.contentType) ?? "")),
            reaction: envelope.reaction != nil,
            parts: parts
        )
    }

    private static func smimeType(_ contentType: String?) -> String? {
        guard let contentType else { return nil }
        for parameter in contentType.split(separator: ";").dropFirst() {
            let pair = parameter.split(separator: "=", maxSplits: 1)
            guard pair.count == 2,
                  pair[0].trimmingCharacters(in: .whitespaces).lowercased() == "smime-type" else { continue }
            return pair[1].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"")).lowercased()
        }
        return nil
    }
}
