import Testing
@testable import PickleQuest

@Suite("Fatigue Model Tests")
struct FatigueModelTests {

    @Test("Energy drains per rally")
    func energyDrainsPerRally() {
        var fatigue = FatigueModel(stamina: 20)
        let initial = fatigue.energy

        _ = fatigue.drainEnergy(rallyLength: 5)
        #expect(fatigue.energy < initial)
    }

    @Test("Higher stamina reduces drain")
    func higherStaminaReducesDrain() {
        var lowStamina = FatigueModel(stamina: 5)
        var highStamina = FatigueModel(stamina: 50)

        _ = lowStamina.drainEnergy(rallyLength: 10)
        _ = highStamina.drainEnergy(rallyLength: 10)

        #expect(highStamina.energy > lowStamina.energy)
    }

    @Test("Energy never goes below zero")
    func energyNeverBelowZero() {
        var fatigue = FatigueModel(stamina: 1)

        for _ in 0..<500 {
            _ = fatigue.drainEnergy(rallyLength: 30)
        }

        #expect(fatigue.energy >= 0)
    }

    @Test("Rest between games restores energy")
    func restRestoresEnergy() {
        var fatigue = FatigueModel(stamina: 20)
        _ = fatigue.drainEnergy(rallyLength: 20)
        let afterDrain = fatigue.energy

        fatigue.restBetweenGames()
        #expect(fatigue.energy > afterDrain)
    }

    @Test("Fatigue levels progress correctly")
    func fatigueLevelsProgress() {
        var fatigue = FatigueModel(stamina: 1)
        #expect(fatigue.fatigueLevel == .fresh)

        // Drain to mild
        while fatigue.energy > GameConstants.Fatigue.threshold1 {
            _ = fatigue.drainEnergy(rallyLength: 10)
        }
        #expect(fatigue.fatigueLevel == .mild)

        // Drain to moderate
        while fatigue.energy > GameConstants.Fatigue.threshold2 {
            _ = fatigue.drainEnergy(rallyLength: 10)
        }
        #expect(fatigue.fatigueLevel == .moderate)

        // Drain to severe
        while fatigue.energy > GameConstants.Fatigue.threshold3 {
            _ = fatigue.drainEnergy(rallyLength: 10)
        }
        #expect(fatigue.fatigueLevel == .severe)
    }
}
