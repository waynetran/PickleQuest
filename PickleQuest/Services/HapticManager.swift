import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    var isEnabled: Bool = true

    private init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }

    func paddleHit() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    func smashHit() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }

    func pointScored() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    func matchWon() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
        notificationFeedback.prepare()
    }

    func matchLost() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
        notificationFeedback.prepare()
    }

    func buttonTap() {
        guard isEnabled else { return }
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
    }

    func lootPickup() {
        guard isEnabled else { return }
        rigidImpact.impactOccurred()
        rigidImpact.prepare()
    }
}
