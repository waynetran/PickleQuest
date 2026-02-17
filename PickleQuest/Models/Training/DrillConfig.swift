import Foundation

enum DrillInputMode: Sendable {
    case joystick
    case swipeToServe
}

struct DrillConfig: Sendable {
    let drillType: DrillType
    let playerStartNX: CGFloat
    let playerStartNY: CGFloat
    let coachStartNX: CGFloat
    let coachStartNY: CGFloat
    let playerMinNY: CGFloat
    let playerMaxNY: CGFloat
    let playerMinNX: CGFloat
    let playerMaxNX: CGFloat
    let inputMode: DrillInputMode
    let rallyShotsRequired: Int
    let totalRounds: Int
    let showConeTargets: Bool

    /// Human-readable instructions shown before the drill starts.
    let instructions: String

    static func config(for drill: DrillType) -> DrillConfig {
        switch drill {
        case .baselineRally:
            return DrillConfig(
                drillType: .baselineRally,
                playerStartNX: 0.5, playerStartNY: 0.08,
                coachStartNX: 0.5, coachStartNY: 0.92,
                playerMinNY: 0.0, playerMaxNY: 0.31,
                playerMinNX: 0.0, playerMaxNX: 1.0,
                inputMode: .joystick,
                rallyShotsRequired: 5,
                totalRounds: 5,
                showConeTargets: false,
                instructions: "Rally 5 shots in a row to score a point.\nComplete 5 rallies to finish!\n\nTry Topspin for aggressive drives.\nUse Power + Focus for deep baseline shots."
            )
        case .dinkingDrill:
            return DrillConfig(
                drillType: .dinkingDrill,
                playerStartNX: 0.5, playerStartNY: 0.318,
                coachStartNX: 0.5, coachStartNY: 0.82,
                playerMinNY: 0.15, playerMaxNY: 0.318,
                playerMinNX: 0.0, playerMaxNX: 1.0,
                inputMode: .joystick,
                rallyShotsRequired: 5,
                totalRounds: 5,
                showConeTargets: false,
                instructions: "Dink 5 soft shots in a row to score.\nComplete 5 rallies to finish!\n\nUse Reset for soft dinks over the net.\nSlice keeps the ball low after the bounce."
            )
        case .servePractice:
            return DrillConfig(
                drillType: .servePractice,
                playerStartNX: 0.65, playerStartNY: -0.03,
                coachStartNX: 0.5, coachStartNY: 0.92,
                playerMinNY: -0.05, playerMaxNY: 0.05,
                playerMinNX: 0.0, playerMaxNX: 1.0,
                inputMode: .swipeToServe,
                rallyShotsRequired: 0,
                totalRounds: 10,
                showConeTargets: false,
                instructions: "Swipe up to serve!\nAngle your swipe to aim left or right.\n5 serves each side!\n\nSmooth upward motion — contact at waist level.\nAim small, miss small."
            )
        case .accuracyDrill:
            return DrillConfig(
                drillType: .accuracyDrill,
                playerStartNX: 0.5, playerStartNY: 0.08,
                coachStartNX: 0.75, coachStartNY: 0.92,
                playerMinNY: 0.0, playerMaxNY: 0.31,
                playerMinNX: 0.0, playerMaxNX: 1.0,
                inputMode: .joystick,
                rallyShotsRequired: 0,
                totalRounds: 10,
                showConeTargets: true,
                instructions: "Return the coach's serves!\nAim for the cones on the other side.\n\nUse Focus for pinpoint accuracy.\nAngled shots target the sidelines."
            )
        case .returnOfServe:
            return DrillConfig(
                drillType: .returnOfServe,
                playerStartNX: 0.5, playerStartNY: 0.08,
                coachStartNX: 0.25, coachStartNY: 0.95,
                playerMinNY: 0.0, playerMaxNY: 0.31,
                playerMinNX: 0.0, playerMaxNX: 1.0,
                inputMode: .joystick,
                rallyShotsRequired: 0,
                totalRounds: 10,
                showConeTargets: true,
                instructions: "Return the coach's cross-court serves!\nAim for the cones on their side.\n\nDeep returns pin the server back.\nUse Focus + Angled for cone targets."
            )
        }
    }
}
