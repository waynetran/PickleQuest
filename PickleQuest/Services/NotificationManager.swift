import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private(set) var permissionGranted = false

    private init() {}

    // MARK: - Permission

    func requestPermissionIfNeeded() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                permissionGranted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                permissionGranted = false
            }
        case .authorized, .provisional:
            permissionGranted = true
        default:
            permissionGranted = false
        }
    }

    // MARK: - Schedule

    func scheduleContestedDropExpiring(dropID: String, dropName: String, expiresAt: Date) {
        let interval = expiresAt.timeIntervalSinceNow - 30 * 60
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Contested Drop Expiring!"
        content.body = "\(dropName) disappears in 30 minutes. Get there before someone else!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: "contested-drop-\(dropID)", content: content, trigger: trigger)
        center.add(request)
    }

    func cancelContestedDrop(dropID: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["contested-drop-\(dropID)"])
    }

    func scheduleTrailExpiring(trailID: String, trailName: String, expiresAt: Date) {
        let interval = expiresAt.timeIntervalSinceNow - 15 * 60
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Trail Expiring!"
        content.body = "\(trailName) expires in 15 minutes. Finish it for bonus rewards!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: "trail-\(trailID)", content: content, trigger: trigger)
        center.add(request)
    }

    func cancelTrail(trailID: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["trail-\(trailID)"])
    }

    func scheduleDailyChallengeReset() {
        // Remove old one first
        center.removePendingNotificationRequests(withIdentifiers: ["daily-challenge"])

        let content = UNMutableNotificationContent()
        content.title = "New Daily Challenge!"
        content.body = "A fresh challenge awaits. Hit the courts and earn bonus rewards!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-challenge", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleEnergyFull(currentEnergy: Double) {
        guard currentEnergy < GameConstants.PersistentEnergy.maxEnergy else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["energy-full"])

        let minutesToFull = (GameConstants.PersistentEnergy.maxEnergy - currentEnergy)
            / GameConstants.PersistentEnergy.recoveryPerMinute
        let seconds = minutesToFull * 60
        guard seconds > 60 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Energy Full!"
        content.body = "Your energy is fully recovered. Time to get back on the court!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "energy-full", content: content, trigger: trigger)
        center.add(request)
    }

    func cancelEnergyFull() {
        center.removePendingNotificationRequests(withIdentifiers: ["energy-full"])
    }

    func scheduleCourtCacheReady(courtID: String, courtName: String, cooldownEnd: Date) {
        let interval = cooldownEnd.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Court Cache Ready!"
        content.body = "The cache at \(courtName) has refreshed. Swing by to collect!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: "court-cache-\(courtID)", content: content, trigger: trigger)
        center.add(request)
    }
}
