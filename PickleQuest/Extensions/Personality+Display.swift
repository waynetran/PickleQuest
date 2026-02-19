import Foundation

extension Personality {
    var displayName: String {
        switch self {
        case .awkward: return "Awkward"
        case .serious: return "Serious"
        case .funny: return "Funny"
        case .dramatic: return "Dramatic"
        case .flirty: return "Flirty"
        case .competitive: return "Competitive"
        }
    }

    var displayDescription: String {
        switch self {
        case .awkward: return "Endearingly unsure. You stumble through conversations but people root for you."
        case .serious: return "All business on the court. You analyze, strategize, and stay focused."
        case .funny: return "Life of the court. You crack jokes win or lose — pickleball is supposed to be fun."
        case .dramatic: return "Every point is a saga. Every win is legendary. Every loss is a tragedy."
        case .flirty: return "Charming and playful. You compliment opponents and keep things light."
        case .competitive: return "Driven to win. You respect the game and push yourself every match."
        }
    }

    var displayIcon: String {
        switch self {
        case .awkward: return "face.smiling.inverse"
        case .serious: return "eyeglasses"
        case .funny: return "face.smiling"
        case .dramatic: return "theatermasks"
        case .flirty: return "heart"
        case .competitive: return "trophy"
        }
    }

    var sampleQuote: String {
        switch self {
        case .awkward: return "That was... um... good? I think? Sorry."
        case .serious: return "Well played. Let's analyze what worked."
        case .funny: return "I'd say good game, but I'm not sure what that was!"
        case .dramatic: return "The court trembles before my POWER!"
        case .flirty: return "Nice shot, handsome. I mean... the ball."
        case .competitive: return "One more point. I'm NOT losing this."
        }
    }
}
