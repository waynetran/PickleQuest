import Foundation

/// Dialog tables mapping Personality × Context → lines.
/// Used for NPC post-match quips, player reactions, and in-game commentary.
enum PersonalityDialog {
    enum Context: Sendable {
        case postMatchWin
        case postMatchLoss
        case pointWon
        case pointLost
        case aceHit
        case errorMade
    }

    static func randomLine(for personality: Personality, context: Context) -> String {
        let pool: [String]
        switch context {
        case .postMatchWin: pool = postMatchWin[personality] ?? postMatchWin[.competitive]!
        case .postMatchLoss: pool = postMatchLoss[personality] ?? postMatchLoss[.competitive]!
        case .pointWon: pool = pointWon[personality] ?? pointWon[.competitive]!
        case .pointLost: pool = pointLost[personality] ?? pointLost[.competitive]!
        case .aceHit: pool = aceHit[personality] ?? aceHit[.competitive]!
        case .errorMade: pool = errorMade[personality] ?? errorMade[.competitive]!
        }
        return pool.randomElement() ?? "Good game!"
    }

    // MARK: - Post-Match Win

    private static let postMatchWin: [Personality: [String]] = [
        .awkward: [
            "That was... um...\ngood? I think? Sorry.",
            "Did I really win?\nOh wow. Neat.",
            "Sorry about that\nlast shot. But yay?",
            "I hope you're not\nmad at me...",
        ],
        .serious: [
            "Well played.\nLet's analyze what worked.",
            "A solid performance.\nRoom to improve still.",
            "Good match.\nI'll review the tape.",
            "Execution was clean today.\nConsistency is key.",
        ],
        .funny: [
            "I'd say good game, but\nI'm not sure what that was! 😂",
            "My paddle did all\nthe work honestly 🏓",
            "GG! I accept my trophy\nin pickle form 🥒",
            "That was fun!\nSame time never? JK 😄",
        ],
        .dramatic: [
            "The court TREMBLES\nbefore my POWER! 👑",
            "And so the legend\nGROWS! ✨",
            "Destiny has spoken!\nI was born for this!",
            "A MASTERPIECE\nof pickleball! 🎭",
        ],
        .flirty: [
            "Nice shots, cutie.\nMaybe next time 😘",
            "You're cute when\nyou're losing 💕",
            "Let's do this again.\nI like the company 😉",
            "Winner buys drinks?\nWait, that's me 🍹",
        ],
        .competitive: [
            "One more point.\nI'm NOT losing this.",
            "That's a W.\nAdd it to the board. 💪",
            "Winning never\ngets old. Ever.",
            "Dominated.\nWho's next?",
        ],
    ]

    // MARK: - Post-Match Loss

    private static let postMatchLoss: [Personality: [String]] = [
        .awkward: [
            "Oh no... that was\nembarrassing, huh?",
            "Well um... at least\nI tried? Sorry.",
            "I'll just... go now.\nGood game though!",
            "Did everyone see that?\nPlease say no.",
        ],
        .serious: [
            "I need to review\nmy strategy.",
            "Adjustments needed.\nBack to practice.",
            "You exposed a weakness.\nI'll address it.",
            "A learning experience.\nEvery loss teaches.",
        ],
        .funny: [
            "Well THAT happened 😅",
            "I blame the wind.\nWhat wind? Exactly. 💨",
            "My paddle betrayed me.\nWe're in couples therapy.",
            "At least I got\nmy steps in! 👟",
        ],
        .dramatic: [
            "IMPOSSIBLE!\nThis cannot be! 😱",
            "The fates are cruel!\nCRUEL I say!",
            "My legacy... tarnished!\nBut not forever! 🎭",
            "A mere setback\nin my epic saga!",
        ],
        .flirty: [
            "You win this time.\nBut you owe me dinner 😏",
            "Losing to someone cute\nhurts less somehow 💔",
            "Rematch? I'll try harder\nif you smile more 😉",
            "Okay you're good.\nAnd also cute. Bye 🫣",
        ],
        .competitive: [
            "Rematch. NOW.",
            "That won't happen again.\nMark my words.",
            "I HATE losing.\nThis fuels me. 🔥",
            "One loss doesn't\ndefine me. Next.",
        ],
    ]

    // MARK: - Point Won

    private static let pointWon: [Personality: [String]] = [
        .awkward: ["Oh! I got it!", "Wait, really?", "Sorry! 😅"],
        .serious: ["Solid.", "Good execution.", "As planned."],
        .funny: ["BOOM baby! 💥", "Did you see that?!", "I meant to do that 😂"],
        .dramatic: ["WITNESS ME! ✨", "LEGENDARY!", "BOW! 👑"],
        .flirty: ["That one's for you 😘", "Like what you see? 💕", "Watch this 😉"],
        .competitive: ["LET'S GO! 💪", "That's mine!", "Come on!"],
    ]

    // MARK: - Point Lost

    private static let pointLost: [Personality: [String]] = [
        .awkward: ["Oops...", "My bad 😰", "S-sorry..."],
        .serious: ["Adjust.", "Noted.", "Focus."],
        .funny: ["Okay that one hurt 😂", "Rude! 😤", "I'll allow it..."],
        .dramatic: ["NOOOO! 😱", "Cursed!", "Betrayal!"],
        .flirty: ["Nice shot, cutie 💕", "Okay, impressive 😏", "You're trouble 😈"],
        .competitive: ["Not again!", "Come ON!", "Focus up! 😤"],
    ]

    // MARK: - Ace Hit

    private static let aceHit: [Personality: [String]] = [
        .awkward: ["Did... did I just ace?!", "Oh wow sorry!", "That went in?!"],
        .serious: ["Clean serve.", "Textbook.", "Perfect placement."],
        .funny: ["ACE! 🎯 I'm basically\na pro now", "UNTOUCHABLE! 😎", "Magic paddle! ✨"],
        .dramatic: ["BEHOLD MY SERVE! ⚡", "A THUNDERBOLT!", "UNSTOPPABLE!"],
        .flirty: ["Too fast for you?\nSorry babe 😘", "All power, all beauty 💪", "Impressed yet? 😉"],
        .competitive: ["ACE! Let's GO! 🔥", "Can't touch this!", "That's what I do."],
    ]

    // MARK: - Error Made

    private static let errorMade: [Personality: [String]] = [
        .awkward: ["Oh no oh no...", "I'm so sorry!", "Ugh, me again 😰"],
        .serious: ["Unacceptable.", "Fix that.", "Concentrate."],
        .funny: ["My arm did a thing 😂", "Physics betrayed me!", "Oops! 🤷"],
        .dramatic: ["WHAT HAVE I DONE?!", "The horror!", "A tragedy!"],
        .flirty: ["Oops! Distracted\nby the view 😏", "Don't look at me! 🫣", "That was on purpose.\n...no it wasn't."],
        .competitive: ["Come ON!", "Not acceptable!", "Get it together! 😤"],
    ]
}

// MARK: - NPC Dialog Personality

extension NPC {
    /// Deterministic dialog personality derived from NPC ID.
    var dialogPersonality: Personality {
        let bytes = Array(id.uuidString.utf8)
        let hash = bytes.reduce(0) { ($0 &* 31) &+ Int($1) }
        let cases = Personality.allCases
        return cases[abs(hash) % cases.count]
    }
}
