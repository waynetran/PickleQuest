import Foundation

enum CoachPersonalityType: String, CaseIterable, Codable, Sendable {
    case enthusiastic
    case grumpy
    case chill
    case jokester
    case drill_sergeant
    case zen
    case hype

    var displayName: String {
        switch self {
        case .enthusiastic: return "Enthusiastic"
        case .grumpy: return "Grumpy"
        case .chill: return "Chill"
        case .jokester: return "Jokester"
        case .drill_sergeant: return "Drill Sergeant"
        case .zen: return "Zen"
        case .hype: return "Hype"
        }
    }
}

struct CoachPersonality: Sendable {
    let type: CoachPersonalityType

    // MARK: - Good Shot

    func goodShotLine() -> String {
        let lines: [String]
        switch type {
        case .enthusiastic:
            lines = [
                "Yes!! That's what I'm talking about!",
                "Incredible shot! You're on fire!",
                "Now THAT'S how you play pickleball!",
                "Wow, that was beautiful!",
                "Keep that up and you'll go pro!",
                "That shot gave me chills!",
            ]
        case .grumpy:
            lines = [
                "Hmph. That was... acceptable.",
                "Fine. That one was decent.",
                "Don't let it go to your head.",
                "Okay, you got lucky there.",
                "Even a broken clock is right twice a day.",
                "I've seen worse. Barely.",
            ]
        case .chill:
            lines = [
                "Nice one, dude.",
                "Smooth. Real smooth.",
                "That's the vibe right there.",
                "Cool shot. No rush, no stress.",
                "Easy breezy. Love it.",
                "See? Just feel the flow.",
            ]
        case .jokester:
            lines = [
                "That shot was so clean it did the dishes!",
                "You're making this look easy! ...Are you cheating?",
                "Alert the media — we have a natural!",
                "My grandma called, she wants her paddle back. Just kidding, great shot!",
                "That was so good I almost smiled. Almost.",
                "If shots were pizza, that one was extra cheese!",
            ]
        case .drill_sergeant:
            lines = [
                "Solid execution! Again!",
                "That's the form I want! Don't stop!",
                "Outstanding! Now give me ten more!",
                "Textbook! Keep that discipline!",
                "No time to celebrate — next shot!",
                "Precision! That's what wins matches!",
            ]
        case .zen:
            lines = [
                "Your paddle and the ball are one.",
                "Harmony. Balance. Perfect.",
                "You felt that one, didn't you?",
                "The court rewards those who are present.",
                "Breathe it in. That was mindful play.",
                "Like water finding its path.",
            ]
        case .hype:
            lines = [
                "LET'S GOOOOO!!",
                "OH MY GOD THAT WAS INSANE!!",
                "THE CROWD GOES WILD!!",
                "ABSOLUTELY FILTHY SHOT!!",
                "YOU ARE UNSTOPPABLE RIGHT NOW!!",
                "I CAN'T EVEN — THAT WAS AMAZING!!",
            ]
        }
        return lines.randomElement()!
    }

    // MARK: - Miss / Bad Shot

    func missLine() -> String {
        let lines: [String]
        switch type {
        case .enthusiastic:
            lines = [
                "No worries! You'll get the next one!",
                "Shake it off — I believe in you!",
                "Every miss is a lesson! Let's go!",
                "That's okay! Stay positive!",
                "Hey, even the pros miss sometimes!",
                "You're still doing great — keep pushing!",
            ]
        case .grumpy:
            lines = [
                "What was that? My eyes hurt.",
                "Were you even trying?",
                "I didn't wake up early for this.",
                "You owe me for watching that shot.",
                "Try using the paddle next time.",
                "My coffee is getting cold and so is your game.",
            ]
        case .chill:
            lines = [
                "All good, no stress.",
                "It happens. Reset and chill.",
                "Shake it off, plenty more coming.",
                "No big deal. Stay loose.",
                "Can't win 'em all. You're fine.",
                "Just vibes. Try again.",
            ]
        case .jokester:
            lines = [
                "I think the ball is allergic to your paddle!",
                "Did you close your eyes? Be honest.",
                "That shot went on vacation without you!",
                "Plot twist: the net won that round.",
                "That's what we call a 'character-building' shot!",
                "The ball said 'see ya!' and meant it.",
            ]
        case .drill_sergeant:
            lines = [
                "Get your feet moving! Hustle!",
                "Unacceptable! Reset and focus!",
                "Watch the ball! Eyes forward!",
                "Footwork first, then the shot! Again!",
                "No excuses! You know the drill!",
                "Discipline! Don't let that happen again!",
            ]
        case .zen:
            lines = [
                "Let it go. The next moment awaits.",
                "Even the greatest river has obstacles.",
                "Your mind wandered. Bring it back.",
                "Failure is the shadow of growth.",
                "Do not judge the miss. Observe it.",
                "Breathe. Center. Try again.",
            ]
        case .hype:
            lines = [
                "That's okay — COMEBACK TIME BABY!!",
                "Missed it BUT THE ENERGY IS STILL THERE!!",
                "DOESN'T MATTER — next one is YOURS!!",
                "The hype doesn't stop for one miss!!",
                "Shake it off and come back HARDER!!",
                "WE'RE NOT DONE YET!!",
            ]
        }
        return lines.randomElement()!
    }

    // MARK: - Rally Complete

    func rallyCompleteLine(requiredShots: Int) -> String {
        let lines: [String]
        switch type {
        case .enthusiastic:
            lines = [
                "You did it! \(requiredShots) in a row — amazing!",
                "Rally complete! That was incredible!",
                "Woohoo! \(requiredShots) straight! You're a machine!",
                "That's a full rally! I'm so proud!",
            ]
        case .grumpy:
            lines = [
                "Finally. \(requiredShots) in a row. Only took you long enough.",
                "Okay, that was a real rally. I'll give you that.",
                "Hmph. \(requiredShots) returns. I suppose that's adequate.",
                "Don't celebrate yet. Do it again.",
            ]
        case .chill:
            lines = [
                "Nice, \(requiredShots) in a row. Chill rally.",
                "That's a wrap on that rally. Smooth.",
                "Clean rally, clean vibes.",
                "Easy does it. Rally in the bag.",
            ]
        case .jokester:
            lines = [
                "\(requiredShots) in a row! Did someone turn on easy mode?",
                "Rally complete! Quick, someone get the confetti!",
                "That rally was longer than my attention span!",
                "Achievement unlocked: Rally Master! ...I just made that up.",
            ]
        case .drill_sergeant:
            lines = [
                "\(requiredShots) returns! Mission accomplished! Next rally!",
                "Rally complete! No time to rest — go again!",
                "That's how it's done! Execute the next one!",
                "Objective achieved! Don't lose that momentum!",
            ]
        case .zen:
            lines = [
                "\(requiredShots) returns, one breath at a time.",
                "The rally is complete. Observe the calm after.",
                "Flow achieved. This is your natural state.",
                "Five moments of presence. Well done.",
            ]
        case .hype:
            lines = [
                "\(requiredShots) IN A ROW!! THIS IS INSANE!!",
                "RALLY COMPLETE!! YOU'RE A LEGEND!!",
                "OH YEAH!! FULL RALLY BABY!!",
                "UNSTOPPABLE!! \(requiredShots) STRAIGHT!!",
            ]
        }
        return lines.randomElement()!
    }

    // MARK: - Cone Hit

    func coneHitLine() -> String {
        let lines: [String]
        switch type {
        case .enthusiastic:
            lines = [
                "Right on the cone! Bullseye!",
                "Target hit! Your aim is on point!",
                "Nailed it! Great accuracy!",
            ]
        case .grumpy:
            lines = [
                "You actually hit the cone. Shocking.",
                "Lucky shot. Hit another one to prove it.",
                "The cone didn't dodge. You're welcome.",
            ]
        case .chill:
            lines = [
                "Cone hit. Smooth aim.",
                "Right on target. Easy.",
                "Nice placement, dude.",
            ]
        case .jokester:
            lines = [
                "That cone had a family!",
                "Cone: destroyed. Self-esteem: boosted!",
                "You vs. cones: you're winning!",
            ]
        case .drill_sergeant:
            lines = [
                "Target acquired and destroyed!",
                "Confirmed hit! Maintain accuracy!",
                "Direct hit! That's precision!",
            ]
        case .zen:
            lines = [
                "The cone called. You answered.",
                "Aim with intention. Hit with purpose.",
                "Target and paddle, united.",
            ]
        case .hype:
            lines = [
                "CONE HIT!! LETHAL ACCURACY!!",
                "BOOM!! RIGHT ON TARGET!!",
                "SNIPER SHOT!! CONE DOWN!!",
            ]
        }
        return lines.randomElement()!
    }

    // MARK: - Serve In

    func serveInLine() -> String {
        let lines: [String]
        switch type {
        case .enthusiastic:
            lines = [
                "Great serve! That was perfect!",
                "In! Beautiful placement!",
                "What a serve! Keep it up!",
            ]
        case .grumpy:
            lines = [
                "At least it went in.",
                "Adequate serve. Don't get cocky.",
                "In. Barely. But in.",
            ]
        case .chill:
            lines = [
                "Clean serve. Nice.",
                "In the box. Easy money.",
                "That'll do. Smooth.",
            ]
        case .jokester:
            lines = [
                "In! The serve gods smile upon you!",
                "That serve had GPS installed!",
                "Ace! Well, not really, but it was in!",
            ]
        case .drill_sergeant:
            lines = [
                "Good serve! Maintain that form!",
                "In! That's the standard — hold it!",
                "Serve confirmed! Fire another!",
            ]
        case .zen:
            lines = [
                "The serve found its home.",
                "Release and trust. It landed well.",
                "Purpose in every motion.",
            ]
        case .hype:
            lines = [
                "SERVE IS IN!! BOOM!!",
                "PERFECT PLACEMENT!! LET'S GO!!",
                "WHAT A SERVE!! FIRE!!",
            ]
        }
        return lines.randomElement()!
    }

    // MARK: - Serve Fault

    func serveFaultLine() -> String {
        let lines: [String]
        switch type {
        case .enthusiastic:
            lines = [
                "Oops! Adjust the angle a bit!",
                "Almost! Try a little less power!",
                "You'll nail it next time!",
            ]
        case .grumpy:
            lines = [
                "Fault. Obviously.",
                "That serve was offensive. Not in a good way.",
                "Try aiming for the court next time.",
            ]
        case .chill:
            lines = [
                "Just a fault. No worries.",
                "Missed the box. Dial it back.",
                "It happens. Adjust and retry.",
            ]
        case .jokester:
            lines = [
                "That serve had a mind of its own!",
                "Fault! The net says 'not today!'",
                "The ball wanted to explore outside the court!",
            ]
        case .drill_sergeant:
            lines = [
                "Fault! Check your toss! Again!",
                "Out of bounds! Tighten up!",
                "Unacceptable! Correct and fire!",
            ]
        case .zen:
            lines = [
                "The serve drifted. Recenter your mind.",
                "A fault is a teacher in disguise.",
                "Let go of the miss. Prepare for the next.",
            ]
        case .hype:
            lines = [
                "FAULT — BUT WHO CARES, NEXT ONE!!",
                "DOESN'T MATTER — STAY HYPED!!",
                "MISSED BUT THE ENERGY STAYS UP!!",
            ]
        }
        return lines.randomElement()!
    }

    // MARK: - End of Drill

    func drillEndLine(grade: PerformanceGrade) -> String {
        switch type {
        case .enthusiastic:
            switch grade {
            case .perfect, .great: return "That was AMAZING! You're a natural!"
            case .good: return "Great work! You're really improving!"
            case .okay: return "Good effort! Every rep makes you better!"
            case .poor: return "We all start somewhere — you'll get there!"
            }
        case .grumpy:
            switch grade {
            case .perfect, .great: return "Okay, I'll admit it. That was good."
            case .good: return "Not terrible. Could've been worse."
            case .okay: return "Mediocre. But at least you showed up."
            case .poor: return "I've seen better. From beginners. Much better."
            }
        case .chill:
            switch grade {
            case .perfect, .great: return "Dude, you crushed it. Respect."
            case .good: return "Solid session. Good vibes all around."
            case .okay: return "Not bad. Room to grow, no rush."
            case .poor: return "Hey, you showed up. That's what counts."
            }
        case .jokester:
            switch grade {
            case .perfect, .great: return "Were you secretly a pro this whole time?!"
            case .good: return "Not bad! I'd give it a solid B+... okay fine, B."
            case .okay: return "Hey, at least the cones survived! ...most of them."
            case .poor: return "The paddle is the flat thing. Just checking!"
            }
        case .drill_sergeant:
            switch grade {
            case .perfect, .great: return "Outstanding performance! Dismissed with honors!"
            case .good: return "Solid drill! But there's always room for improvement!"
            case .okay: return "Below expectations! Double drills tomorrow!"
            case .poor: return "Report back at 0600 for remedial training!"
            }
        case .zen:
            switch grade {
            case .perfect, .great: return "You were truly present today. Masterful."
            case .good: return "Good energy. Your focus is growing."
            case .okay: return "The journey matters more than the score."
            case .poor: return "Even the tallest mountain begins at the base."
            }
        case .hype:
            switch grade {
            case .perfect, .great: return "THAT WAS THE GREATEST DRILL I'VE EVER SEEN!!"
            case .good: return "SOLID SESSION!! YOU'RE GETTING BETTER!!"
            case .okay: return "GOOD EFFORT!! NEXT TIME WE GO HARDER!!"
            case .poor: return "THE COMEBACK STARTS NOW!! LET'S RUN IT BACK!!"
            }
        }
    }
}
