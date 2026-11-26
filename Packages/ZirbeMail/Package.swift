// swift-tools-version:6.0
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import PackageDescription

// ZirbeMail is Zirbe's thin adapter over Cocoanetics/SwiftMail. SwiftMail does
// the IMAP/SMTP work; ZirbeMail exposes only the Zirbe-owned value types the
// rest of the app uses, so the underlying engine stays swappable.
let package = Package(
    name: "ZirbeMail",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "ZirbeMail", targets: ["ZirbeMail"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Cocoanetics/SwiftMail", exact: "1.9.2"),
        // swift-nio-imap 0.5.0 declares iOS 18 as its floor, above SwiftMail's own
        // iOS 15 target, which Xcode refuses. 0.3.0 is the version SwiftMail 1.9.2
        // is built and tested against.
        .package(url: "https://github.com/apple/swift-nio-imap", exact: "0.3.0"),
        // Klartext reduces an HTML body to text (MailEngine's fetch path). Content
        // only, on-device, SwiftSoup-backed.
        .package(url: "https://github.com/excelano/klartext", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "ZirbeMail",
            dependencies: [
                .product(name: "SwiftMail", package: "SwiftMail"),
                .product(name: "Klartext", package: "klartext"),
            ]
        ),
        // macOS-only example. Exercises the adapter against a real account
        // using IMAP_* environment variables; not part of any app.
        .executableTarget(
            name: "imap-demo",
            dependencies: ["ZirbeMail"]
        ),
        // macOS-only: dump recent messages' iCalendar parts as parser fixtures.
        .executableTarget(
            name: "ics-dump",
            dependencies: [.product(name: "SwiftMail", package: "SwiftMail")]
        ),
        .testTarget(
            name: "ZirbeMailTests",
            dependencies: [
                "ZirbeMail",
                // The attachment tests build SwiftMail MessagePart fixtures to
                // exercise the adapter's MIME-structure extraction directly.
                .product(name: "SwiftMail", package: "SwiftMail"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
