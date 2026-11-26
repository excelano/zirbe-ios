# Zirbe

An open-source email client for iPhone and iPad that looks and feels like a
texting app, while keeping real email underneath. Standards-only, no backend.
On iPad the conversation list sits beside the open conversation. It follows
[zirbe-desktop](https://github.com/excelano/zirbe-desktop), the Linux desktop
app, which is the primary Zirbe app.

https://excelano.com/zirbe/ is the product page for every platform.

## The name

*Zirbe* is German for the Swiss stone pine, the pine of the Alps. The name
continues a lineage of text-mode mail clients that runs **Elm → Pine → Alpine**,
and lands on another pine. The hidden meaning is the point: it reads like a
coined word and rewards anyone who looks it up.

## What it is

A conversation in Zirbe is an email **thread**, not a person, shown like a
named group chat: the **subject is the title**, the people on the thread are
the members, and each message is one bubble in time order.
[CONVERSATIONS.md](https://github.com/excelano/zirbe-desktop/blob/main/CONVERSATIONS.md) defines how messages are grouped, when a
private reply starts a conversation of its own, and how reactions travel.
Starting a new conversation requires naming it, and that name is the subject.

## Principles

Apple Messages is the aesthetic muse, never a clone. I implement only what the
email RFCs define (5321 SMTP, 5322 message format, 2045/2046/2047 MIME) and
nothing that isn't email: no video or voice calls, no shared notes, tasks, or
team workspaces. There is no backend, no third-party SDK and no
telemetry. Credentials and tokens live in the Keychain, device-bound, never
synced off the device that obtained them. The only network destinations are the
user's own IMAP and SMTP servers and, for a Microsoft account, Microsoft's sign-in
service. [PRIVACY.md](PRIVACY.md) states this in full, and
[SECURITY.md](SECURITY.md) says what the app can reach and what it keeps.

## How it is built

The mail engine is [Cocoanetics/SwiftMail](https://github.com/Cocoanetics/SwiftMail),
a mature actor-based async IMAP and SMTP client, consumed through a thin adapter
in `Packages/ZirbeMail` (a `MailEngine` actor returning Zirbe-owned value types,
so the engine stays swappable). Email content parsing — HTML to text, quote
folding, signatures, inline images — comes from the shared
[Klartext](https://github.com/excelano/klartext) package.

## Building

Open `Zirbe/Zirbe.xcodeproj` in Xcode to build and run the app. The domain and
mail layers are Swift packages under `Packages/`, each with its own test suite,
run with `swift test` in the package's folder on a Mac. ZirbeCore's tests
drive the sync and send paths against an in-memory IMAP server and SMTP sender,
so no account or network is needed.

> [!WARNING]
> Do NOT submit Zirbe, or a copy of it under another name, to the App Store. Apple's
> App Review Guideline 4.3 treats copies of other apps as spam, and a 4.3
> finding can flag the developer account that submitted it, so that every app
> the account sends afterwards is flagged too. Build it for your own devices and keep
> it there.

## License

MIT. See [LICENSE](LICENSE).
