import Testing
@testable import PickleQuest

@Suite("HustlerNPCGenerator Tests")
struct HustlerNPCGeneratorTests {

    @Test("Generates exactly 3 hustlers")
    func generatesThree() {
        let hustlers = HustlerNPCGenerator.generateHustlers()
        #expect(hustlers.count == GameConstants.Wager.hustlerCount)
    }

    @Test("All hustlers have isHustler flag set")
    func allAreHustlers() {
        let hustlers = HustlerNPCGenerator.generateHustlers()
        for hustler in hustlers {
            #expect(hustler.isHustler)
        }
    }

    @Test("All hustlers have hidden stats")
    func allHaveHiddenStats() {
        let hustlers = HustlerNPCGenerator.generateHustlers()
        for hustler in hustlers {
            #expect(hustler.hiddenStats)
        }
    }

    @Test("All hustlers have non-zero base wager amounts")
    func allHaveWagers() {
        let hustlers = HustlerNPCGenerator.generateHustlers()
        for hustler in hustlers {
            #expect(hustler.baseWagerAmount > 0)
        }
    }

    @Test("Hustler wager amounts are within expected range")
    func wagerAmountsInRange() {
        let hustlers = HustlerNPCGenerator.generateHustlers()
        let wagers = hustlers.map(\.baseWagerAmount).sorted()
        #expect(wagers == [300, 500, 800])
    }

    @Test("Hustlers have deterministic UUIDs")
    func deterministicIDs() {
        let first = HustlerNPCGenerator.generateHustlers()
        let second = HustlerNPCGenerator.generateHustlers()
        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test("Hustlers have unique names")
    func uniqueNames() {
        let hustlers = HustlerNPCGenerator.generateHustlers()
        let names = Set(hustlers.map(\.name))
        #expect(names.count == hustlers.count)
    }

    @Test("Hustlers are advanced or expert difficulty")
    func correctDifficulty() {
        let hustlers = HustlerNPCGenerator.generateHustlers()
        for hustler in hustlers {
            #expect(hustler.difficulty == .advanced || hustler.difficulty == .expert)
        }
    }
}
