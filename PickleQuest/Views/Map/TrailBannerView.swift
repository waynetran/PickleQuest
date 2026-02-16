import SwiftUI

struct TrailBannerView: View {
    let trail: TrailRoute
    let collectedIDs: Set<UUID>

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.walk")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(trail.name)
                    .font(.caption.bold())
                    .lineLimit(1)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray4))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(.orange)
                            .frame(width: geo.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: 100)

            Text("\(collected)/\(trail.totalCount)")
                .font(.caption.bold().monospacedDigit())

            Spacer()

            // Timer
            Text(timeRemaining)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(timeColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    private var collected: Int {
        trail.waypoints.filter { collectedIDs.contains($0.id) }.count
    }

    private var progress: CGFloat {
        guard trail.totalCount > 0 else { return 0 }
        return CGFloat(collected) / CGFloat(trail.totalCount)
    }

    private var timeRemaining: String {
        let remaining = trail.expiresAt.timeIntervalSince(now)
        guard remaining > 0 else { return "0:00" }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var timeColor: Color {
        let remaining = trail.expiresAt.timeIntervalSince(now)
        if remaining < 300 { return .red }
        if remaining < 600 { return .orange }
        return .secondary
    }
}
