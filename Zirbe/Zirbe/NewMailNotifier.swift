// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// The app-side half of local new-mail notifications: it turns the background
// poll's arrivals into banners and routes a tap back to the conversation. The
// decision of what to post is pure and lives in ZirbeCore (NewMailNotification);
// this is the thin UserNotifications shell around it, kept in the app target so
// the package carries no UserNotifications dependency.
//
// There is no instant push, by design — that needs a server the privacy posture
// forbids — so these fire only when iOS grants a background poll, never live.
// While the app is foregrounded the inbox already updates itself over IDLE, so a
// banner there would be noise: willPresent suppresses it.

import Combine
import UserNotifications
import ZirbeCore

@MainActor
final class NewMailNotifier: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NewMailNotifier()

    struct Target: Equatable {
        let accountID: String
        let threadID: String
    }

    /// The conversation a tapped notification wants opened, for RootView to push.
    /// Set on tap (including a cold launch from the lock screen) and cleared once
    /// routed. Published so the view layer can react without polling.
    @Published var pendingTarget: Target?

    /// The notification `userInfo` key carrying the thread to open.
    private static let threadIDKey = "threadID"
    private static let accountIDKey = "accountID"

    private override init() { super.init() }

    /// Become the notification center's delegate. Called once at launch, early
    /// enough to receive a tap that launched the app from a cold start.
    func registerAsDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Ask for notification permission the first time, and only then: a settled
    /// grant or denial is left untouched, so this is safe to call on every connect.
    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Post for the arrivals a background poll found, and set the app badge from
    /// the inbox's `unread` messages. Nothing posts when the user has turned
    /// notifications off or hasn't granted them. Arrivals the user's rules and
    /// conversation alerts exclude are dropped first. A small run posts one banner
    /// each; a larger one collapses to a single summary (NewMailNotification.plan).
    func post(_ arrivals: [NewMailItem], unread: [NewMailItem]) async {
        await updateBadge(unread: unread)
        guard !arrivals.isEmpty, notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }

        for request in requests(for: NewMailNotification.plan(for: arrivals, rules: rules)) {
            try? await center.add(request)
        }
    }

    /// Set the app icon badge to the `unread` inbox messages the notification
    /// rules would let notify, and to nothing while notifications are off: the
    /// badge is a notification shown outside the app (zirbe-desktop's
    /// CONVERSATIONS.md § Notifications). The app calls this whenever its unread
    /// mail or the settings change, so the badge never freezes at the last
    /// poll's number. A no-op without the badge authorization.
    func updateBadge(unread: [NewMailItem]) async {
        let count = notificationsEnabled ? unread.filter(rules.notifies).count : 0
        try? await UNUserNotificationCenter.current().setBadgeCount(count)
    }

    /// Whether the user's "New mail notifications" toggle is on. Defaults on when
    /// the key was never written, matching the Settings toggle's default.
    private var notificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.newMailNotifications) as? Bool ?? true
    }

    /// The user's per-kind choices and Favorites list, read from the settings
    /// keys. A kind never set, or stored as an unknown value, reads as Everyone.
    private var rules: NotificationRules {
        let defaults = UserDefaults.standard
        var who: [MessageKind: NotifyWho] = [:]
        for kind in MessageKind.allCases {
            if let stored = defaults.string(forKey: SettingsKeys.notifyWho(kind)), let choice = NotifyWho(rawValue: stored) {
                who[kind] = choice
            }
        }
        return NotificationRules(who: who, favorites: defaults.string(forKey: SettingsKeys.notifyFavorites) ?? "")
    }

    /// Build the notification requests for a plan: one per banner, or a single
    /// summary. A per-message banner carries its thread id so a tap can open it and
    /// so iOS groups same-thread banners; the summary carries none.
    private func requests(for plan: NewMailNotification.Plan) -> [UNNotificationRequest] {
        func make(title: String, body: String, accountID: String?, threadID: String?) -> UNNotificationRequest {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            var info: [AnyHashable: Any] = [:]
            if let accountID, let threadID {
                content.threadIdentifier = "\(accountID)/\(threadID)"
                info[Self.accountIDKey] = accountID
                info[Self.threadIDKey] = threadID
            }
            content.userInfo = info
            return UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        }
        switch plan {
        case .none:
            return []
        case .summary(let count):
            return [make(title: "New mail", body: "\(count) new messages", accountID: nil, threadID: nil)]
        case .items(let banners):
            return banners.map { make(title: $0.title, body: $0.body, accountID: $0.accountID, threadID: $0.threadID) }
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Suppress the banner while the app is foregrounded: the inbox is already live
    /// over IDLE, so a banner on top of it would only repeat what's on screen.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }

    /// On tap, surface the conversation to open. RootView observes
    /// `pendingThreadID` and pushes it once the inbox is up.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        if let accountID = info[Self.accountIDKey] as? String, let threadID = info[Self.threadIDKey] as? String {
            pendingTarget = Target(accountID: accountID, threadID: threadID)
        }
    }
}
