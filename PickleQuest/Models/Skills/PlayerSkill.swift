import Foundation

struct PlayerSkill: Codable, Equatable, Sendable {
    let skillID: SkillID
    var rank: Int  // 1-5
    let acquiredDate: Date
    let acquiredVia: SkillAcquisitionSource
}

enum SkillAcquisitionSource: String, Codable, Sendable {
    case coaching
    case defeat
}

struct SkillLessonProgress: Codable, Equatable, Sendable {
    var lessonsCompleted: Int  // 0-5, at 5 the skill is acquired
    var coachIDs: Set<String>  // which coaches contributed
}
