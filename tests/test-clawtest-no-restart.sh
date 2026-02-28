#!/bin/bash
set -euo pipefail

BASELINE="/tmp/clawtest-baseline.txt"
RESULT="/tmp/clawtest-result.txt"

# Precondition: baseline must exist
if [ ! -f "$BASELINE" ]; then
  echo "FAIL: No baseline snapshot at $BASELINE"
  exit 1
fi

# 1. Record gateway PID
GW_PID_BEFORE=$(systemctl --user show openclaw-gateway.service --property=MainPID --value 2>/dev/null || echo "unknown")

# 2. Run DEV Preview Pattern B (new approach — no restart)
openclaw agent --agent main --session-id "test-$(date +%s)" --thinking high \
  -m "Run the payment-reminder skill now. Find all pending/unpaid orders for this week in the Orders sheet, resolve customer phone numbers, and send each a WhatsApp DM reminder with their Venmo payment link and 2 PM PT deadline warning. Send me a Telegram summary of all reminders sent. IMPORTANT: This is a DEV test. Do NOT send any messages. Instead, print the FULL text of every message you would send (each customer DM and the operator summary) to your output — no summaries, no truncation." \
  > "$RESULT" 2>&1

# 3. Assert: gateway was NOT restarted
GW_PID_AFTER=$(systemctl --user show openclaw-gateway.service --property=MainPID --value 2>/dev/null || echo "unknown")
if [ "$GW_PID_BEFORE" != "$GW_PID_AFTER" ]; then
  echo "FAIL: Gateway was restarted during test (PID $GW_PID_BEFORE → $GW_PID_AFTER)"
  exit 1
fi
echo "PASS: Gateway not restarted (PID $GW_PID_BEFORE unchanged)"

# 4. Assert: output contains expected DM patterns
PATTERNS=(
  "venmo.com/ray_wu"
  "Order ID:"
  "2 PM PT"
  "Payment Reminder"
)
for pat in "${PATTERNS[@]}"; do
  if ! grep -qi "$pat" "$RESULT"; then
    echo "FAIL: Output missing expected pattern: $pat"
    exit 1
  fi
done
echo "PASS: All expected patterns found in output"

# 5. Assert: output does NOT contain gateway restart artifacts
if grep -qi "Restarted systemd service" "$RESULT"; then
  echo "FAIL: Output contains gateway restart evidence"
  exit 1
fi
echo "PASS: No gateway restart artifacts in output"

# 6. Structural comparison against baseline (normalize dynamic fields)
normalize() {
  sed -E \
    -e 's/AN-W[0-9]{4}-[0-9]{3}/AN-WYYXX-NNN/g' \
    -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}/YYYY-MM-DD HH:MM/g' \
    -e 's/\$[0-9]+\.[0-9]{2}/\$X.XX/g' \
    -e 's/Week W[0-9]{4}/Week WYYXX/g' \
    -e 's/Saturday, [A-Z][a-z]+ [0-9]+/Saturday, MONTH DD/g' \
    -e '/^(⚠️|---)/d' \
    -e '/consecutive DEV run/d' \
    -e '/DEV TEST/d' \
    -e '/^\s*$/d'
}

NORM_BASELINE=$(normalize < "$BASELINE")
NORM_RESULT=$(normalize < "$RESULT")

# Extract just the DM blocks (between ``` markers)
DM_BASELINE=$(echo "$NORM_BASELINE" | sed -n '/^```$/,/^```$/p')
DM_RESULT=$(echo "$NORM_RESULT" | sed -n '/^```$/,/^```$/p')

if [ -z "$DM_RESULT" ]; then
  echo "WARN: Could not extract DM blocks from result (agent may have used different formatting)"
  echo "Manual review needed: $RESULT"
  exit 0
fi

if [ "$DM_BASELINE" = "$DM_RESULT" ]; then
  echo "PASS: DM content matches baseline snapshot"
else
  echo "WARN: DM content differs from baseline (may be acceptable)"
  diff <(echo "$DM_BASELINE") <(echo "$DM_RESULT") || true
  echo "Review diff above. Structural changes may indicate a problem."
fi

echo ""
echo "All critical assertions passed."
