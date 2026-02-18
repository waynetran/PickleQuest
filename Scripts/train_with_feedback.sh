#!/bin/bash
# Runs the NPC stat profile training pipeline, then asks Claude to analyze
# the balance report and determine if results are acceptable.
#
# Usage: ./Scripts/train_with_feedback.sh [max_iterations]
#
# Each iteration:
#   1. Runs StatProfileTrainingTests (ES optimizer + headless validation)
#   2. Reads the generated training_report.txt
#   3. Asks Claude CLI to analyze the report against balance criteria
#   4. If PASS → exits successfully; if FAIL → prints suggestions and loops
#
# Claude's suggestions are printed but NOT auto-applied (safe by default).

set -euo pipefail

MAX_ITER=${1:-3}
REPORT_FILE="PickleQuest/Resources/training_report.txt"
PROFILES_FILE="PickleQuest/Resources/stat_profiles.json"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$PROJECT_DIR"

for i in $(seq 1 "$MAX_ITER"); do
  echo "=== Training iteration $i/$MAX_ITER ==="
  echo ""

  # Run the training test
  xcodebuild test -project PickleQuest.xcodeproj -scheme PickleQuest \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing 'PickleQuestTests/StatProfileTrainingTests' \
    2>&1 | tail -20

  echo ""

  # Check if report was generated
  if [ ! -f "$REPORT_FILE" ]; then
    echo "ERROR: Training report not generated at $REPORT_FILE"
    exit 1
  fi

  echo "=== Analyzing balance report with Claude... ==="

  # Ask Claude to analyze the report
  claude -p "You are a game balance analyst for PickleQuest, a pickleball RPG.
Read this training report and determine if the balance is acceptable.

$(cat "$REPORT_FILE")

Criteria for PASS:
- NPC-vs-NPC point diffs within 20% of targets for all pairs
- Player-vs-NPC balance: player loses by 1-3 points at each DUPR level
- Starter balance: within ±1.0 point diff of target
- Rally length: 4-9 average shots
- No DUPR pair with >95% or <5% win rate

If ALL criteria pass, respond with exactly on the first line: PASS
Then briefly explain why each criterion passed.

If any fail, respond with on the first line: FAIL
Then:
- List specific issues with data from the report
- Suggest specific GameConstants or SimulationParameters adjustments
- Be concise and actionable" > /tmp/claude_analysis.txt

  echo ""

  # Check if Claude said PASS
  if head -1 /tmp/claude_analysis.txt | grep -q "PASS"; then
    echo "=== Balance PASSED on iteration $i ==="
    echo ""
    cat /tmp/claude_analysis.txt
    exit 0
  fi

  echo "=== Iteration $i: Balance needs adjustment ==="
  echo ""
  cat /tmp/claude_analysis.txt
  echo ""

  # If not last iteration, note we're re-running
  if [ "$i" -lt "$MAX_ITER" ]; then
    echo "--- Apply suggested changes manually, then re-run will proceed ---"
    echo "--- Or press Ctrl-C to stop and apply changes before continuing ---"
    echo ""
  fi
done

echo "=== Reached max iterations ($MAX_ITER) without convergence ==="
echo "Review the last analysis in /tmp/claude_analysis.txt"
exit 1
