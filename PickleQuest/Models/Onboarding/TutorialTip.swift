import Foundation
import SwiftUI

struct TutorialTip: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let body: String
    let icon: String
    let accentColor: Color?

    init(title: String, body: String, icon: String, accentColor: Color? = nil) {
        self.title = title
        self.body = body
        self.icon = icon
        self.accentColor = accentColor
    }
}
