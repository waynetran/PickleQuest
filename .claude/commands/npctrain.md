Run the automated NPC stat profile training pipeline, analyze balance, and iterate until all criteria pass.

Steps:
1. Run the training test:
   ```
   xcodebuild test -project PickleQuest.xcodeproj -scheme PickleQuest \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -only-testing 'PickleQuestTests/StatProfileTrainingTests'
   ```
2. If the test fails, show the error output and do NOT commit.
3. If the test passes, read `PickleQuest/Resources/training_report.txt` and analyze balance against these criteria:
   - NPC-vs-NPC point diffs within 20% of targets for all 0.5-gap pairs (target ±20% of +6.0 = 4.8-7.2)
   - NPC-vs-NPC point diffs within 20% of targets for 1.0-gap pairs (target ±20% of +10.5 = 8.4-12.6)
   - Player-vs-NPC balance: player loses by 1-3 points at each DUPR level
   - Starter balance: within ±1.0 point diff of target
   - Headless interactive rally length: 4-9 average shots at each DUPR
   - No DUPR pair with >95% or <5% win rate (except large DUPR gaps like 3.0+)
4. If ALL criteria pass: report PASS, commit, push, and summarize results.
5. If any criteria FAIL: report which specific criteria failed and by how much, then apply targeted fixes:

   **Fix guide (apply the smallest change that addresses the specific failure):**
   - NPC-vs-NPC diffs too low across the board → increase `GameConstants.Rally.statSensitivity` by 0.01
   - NPC-vs-NPC diffs too high across the board → decrease `GameConstants.Rally.statSensitivity` by 0.01
   - Player-vs-NPC diff too small at low DUPRs → increase `npcEquipOffset` in `SimulationParameters.defaults` by 0.5
   - Player-vs-NPC diff too large at high DUPRs → decrease `npcEquipSlope` in `SimulationParameters.defaults` by 0.5
   - Starter balance off → adjust `playerStarterStats` in `SimulationParameters.defaults` (increase stats to reduce deficit, decrease to increase it)
   - Rally length too short → decrease `GameConstants.Rally.baseErrorChance` by 0.01
   - Rally length too long → increase `GameConstants.Rally.baseErrorChance` by 0.01
   - Win rate too extreme for small gaps → decrease `GameConstants.Rally.statSensitivity` by 0.01

   After applying fixes, go back to step 1 and re-run training. Repeat up to 5 iterations.
6. If still failing after 5 iterations, report the remaining issues and stop.

**On success (commit and push):**
- Commit changed files: `stat_profiles.json`, `training_report.txt`, and any tuned constants (`GameConstants.swift`, `SimulationParameters.swift`)
- Commit message: "Update optimized NPC stat profiles from training"
- Push to remote
- Report: fitness score, generation count, iteration count, balance analysis summary, and stat profile overview
