import Foundation

struct TutorialTip: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let body: String
    let icon: String
}
