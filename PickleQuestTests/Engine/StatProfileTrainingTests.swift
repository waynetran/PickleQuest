import Testing
import Foundation
@testable import PickleQuest

@Suite("Stat Profile Training")
struct StatProfileTrainingTests {

    /// Run ES optimizer headlessly and write optimized stat profiles to JSON.
    ///
    /// This test takes ~5-10 minutes. Run explicitly:
    /// ```
    /// xcodebuild test -project PickleQuest.xcodeproj -scheme PickleQuest \
    ///   -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    ///   -only-testing 'PickleQuestTests/StatProfileTrainingTests'
    /// ```
    @Test func trainAndWriteStatProfiles() async throws {
        let session = await TrainingSession()
        let report = await session.start()

        // Write optimized parameters to source tree
        let testFilePath = #filePath // .../PickleQuestTests/Engine/StatProfileTrainingTests.swift
        let testFileURL = URL(fileURLWithPath: testFilePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent() // Engine/
            .deletingLastPathComponent() // PickleQuestTests/
            .deletingLastPathComponent() // repo root
        let outputURL = repoRoot
            .appendingPathComponent("PickleQuest")
            .appendingPathComponent("Resources")
            .appendingPathComponent("stat_profiles.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(report.parameters)
        try jsonData.write(to: outputURL)

        // Write formatted report to text file for automated analysis
        let reportURL = repoRoot
            .appendingPathComponent("PickleQuest")
            .appendingPathComponent("Resources")
            .appendingPathComponent("training_report.txt")
        let reportText = report.formattedReport()
        try reportText.write(to: reportURL, atomically: true, encoding: .utf8)

        // Print summary to test output
        print(reportText)
        print("\nJSON written to: \(outputURL.path)")
        print("Report written to: \(reportURL.path)")

        // Basic sanity checks
        #expect(report.fitnessScore.isFinite, "Fitness should be a finite number")
        #expect(report.generationCount > 0)

        // Verify written file is valid
        let readBack = try Data(contentsOf: outputURL)
        let decoded = try JSONDecoder().decode(SimulationParameters.self, from: readBack)
        #expect(decoded.slopes.count == 11)
        #expect(decoded.offsets.count == 11)
        #expect(decoded.playerStarterStats.count == 11)
        #expect(decoded.npcEquipSlope >= 0)
        #expect(decoded.npcEquipOffset >= 0)
    }
}
