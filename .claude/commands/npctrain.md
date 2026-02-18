Run the automated NPC stat profile training pipeline, analyze balance, and commit the results.

Steps:
1. Run the training test:
   ```
   xcodebuild test -project PickleQuest.xcodeproj -scheme PickleQuest \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -only-testing 'PickleQuestTests/StatProfileTrainingTests'
   ```
2. If the test fails, show the error output and do NOT commit.
3. If the test passes, show the user the updated stat profiles from `PickleQuest/Resources/stat_profiles.json`
4. Read `PickleQuest/Resources/training_report.txt` and analyze the balance against these criteria:
   - NPC-vs-NPC point diffs within 20% of targets for all pairs
   - Player-vs-NPC balance: player loses by 1-3 points at each DUPR level
   - Starter balance: within ±1.0 point diff of target
   - Rally length: 4-9 average shots
   - No DUPR pair with >95% or <5% win rate (except large DUPR gaps like 3.0+)
   Report PASS or FAIL with specific issues and suggested GameConstants/SimulationParameters adjustments.
5. Commit the updated `stat_profiles.json` and `training_report.txt` with message: "Update optimized NPC stat profiles from training"
6. Push to remote
7. Report the results (fitness score, generation count, balance analysis, and a summary of the stat profiles)
