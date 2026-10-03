#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPORT_FILE="${SCRIPT_DIR}/reproducibility-result.json"
RUNS=3

if [ -n "$NODE_PATH_OVERRIDE" ]; then
  NODE_BIN="$NODE_PATH_OVERRIDE"
else
  NODE_BIN="node"
fi

echo "=== M10 Phase 4 Reproducibility Verification ==="
echo "Running runtime-evidence.js ${RUNS} times..."
echo ""

declare -a VERDICTS
declare -a EXIT_CODES
ALL_PASS=true

for i in $(seq 1 $RUNS); do
  echo "--- Run ${i} ---"
  START_TIME=$(date +%s)
  set +e
  ${NODE_BIN} "${SCRIPT_DIR}/runtime-evidence.js" > "${SCRIPT_DIR}/run-${i}-output.txt" 2>&1
  EXIT_CODE=$?
  set -e
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  OVERALL_VERDICT=$(${NODE_BIN} -e "try{const r=require('${SCRIPT_DIR}/runtime-evidence-report.json');console.log(r.overallVerdict||'UNKNOWN')}catch(e){console.log('UNKNOWN')}" 2>/dev/null || echo "UNKNOWN")

  VERDICTS[$((i-1))]="$OVERALL_VERDICT"
  EXIT_CODES[$((i-1))]="$EXIT_CODE"

  echo "Run ${i}: ${OVERALL_VERDICT} (exit=${EXIT_CODE}, duration=${DURATION}s)"

  if [ "$OVERALL_VERDICT" != "PASS" ] || [ "$EXIT_CODE" != "0" ]; then
    ALL_PASS=false
  fi
done

FIRST_VERDICT="${VERDICTS[0]}"
CONSISTENT=true
for i in $(seq 1 $((RUNS-1))); do
  if [ "${VERDICTS[$i]}" != "$FIRST_VERDICT" ]; then
    CONSISTENT=false
  fi
done

REPRODUCIBLE=false
if [ "$ALL_PASS" = "true" ] && [ "$CONSISTENT" = "true" ]; then
  REPRODUCIBLE=true
fi

echo ""
echo "=== Reproducibility Summary ==="
for i in $(seq 1 $RUNS); do
  echo "Run ${i}: ${VERDICTS[$((i-1))]}"
done
echo "Consistent: ${CONSISTENT}"
echo "Reproducible: ${REPRODUCIBLE}, ${RUNS}/${RUNS} PASS"

RUNS_JSON=""
for i in $(seq 1 $RUNS); do
  if [ $i -gt 1 ]; then RUNS_JSON="${RUNS_JSON},"; fi
  RUNS_JSON="${RUNS_JSON} {\"runIndex\": ${i}, \"exitCode\": ${EXIT_CODES[$((i-1))]}, \"overallVerdict\": \"${VERDICTS[$((i-1))]}\"}"
done

cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "totalRuns": ${RUNS},
  "runs": [${RUNS_JSON}],
  "reproducible": ${REPRODUCIBLE},
  "overallVerdicts": ["${VERDICTS[0]}", "${VERDICTS[1]}", "${VERDICTS[2]}"]
}
EOF

echo "Result saved to: ${REPORT_FILE}"

for i in $(seq 1 $RUNS); do
  rm -f "${SCRIPT_DIR}/run-${i}-output.txt"
done

if [ "$REPRODUCIBLE" = "true" ]; then
  exit 0
else
  exit 1
fi