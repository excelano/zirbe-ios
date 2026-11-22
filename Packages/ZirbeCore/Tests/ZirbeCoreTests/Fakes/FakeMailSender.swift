// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// An in-memory SMTP sender for tests: records what was sent and with which
// login, and can be told to refuse the next send (or every send) so the failed
// bubble and retry paths can be driven without a server.

import Foundation
import ZirbeMail

actor FakeMailSender: SMTPTransport {
    struct Delivery: Equatable {
        let message: OutgoingMessage
        let username: String
    }

    struct ScriptedFailure: Error, Equatable {}

    /// Every successful send, in order.
    private(set) var deliveries: [Delivery] = []
    /// Every attempt, including the ones that failed, in order.
    private(set) var attempts: [OutgoingMessage] = []

    private var failOnce = false
    private var failAlways = false
    private var refusal: Error?

    /// Refuse the next send, then deliver normally.
    func failNext() { failOnce = true }

    /// Refuse every send until `succeed` is called.
    func fail() { failAlways = true }

    /// Refuse the next send with this error, as a server refusing outright would.
    func refuseNext(with error: Error) { refusal = error }

    /// Clear a standing refusal.
    func succeed() { failAlways = false }

    /// The delivered messages alone, for the common assertion.
    var sent: [OutgoingMessage] { deliveries.map(\.message) }

    func send(_ outgoing: OutgoingMessage, username: String, login: MailLogin) async throws {
        attempts.append(outgoing)
        if let refusal {
            self.refusal = nil
            throw refusal
        }
        if failOnce || failAlways {
            failOnce = false
            throw ScriptedFailure()
        }
        deliveries.append(Delivery(message: outgoing, username: username))
    }
}
