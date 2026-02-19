import SwiftUI

struct SkillUnlockedBanner: View {
    let skillName: String
    let skillIcon: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: skillIcon)
                .font(.title2)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("Skill Unlocked!")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(skillName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.purple.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .purple.opacity(0.3), radius: 8, y: 2)
        .padding(.horizontal)
    }
}
