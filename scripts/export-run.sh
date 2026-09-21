#!/bin/bash
# export-run.sh — run ON THE VM HOST after a challenge run ends.
# Pulls the full capture bundle out of the guest into ~/tta-runs/<RUN_ID>/ and
# drops the viewer page next to it, then you can open index.html to watch.
# Usage: ./export-run.sh <vm-name> <run-id>     e.g. ./export-run.sh run-calc-A-basic-1 calc-A-basic-1
set -euo pipefail
VM="${1:?vm name required}"; RUN="${2:?run id required}"
IP=$(tart ip "$VM")
OUT="$HOME/tta-runs/$RUN"
mkdir -p "$OUT"
SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SCP="scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "== exporting $RUN from $VM ($IP) =="
$SCP "admin@$IP:~/challenge"           "$OUT/repo"            2>/dev/null || echo "  (no ~/challenge)"
$SCP "admin@$IP:~/.claude/projects"    "$OUT/transcripts"     2>/dev/null || echo "  (no transcripts)"
$SCP "admin@$IP:~/tta/stills"          "$OUT/stills"          2>/dev/null || echo "  (no stills)"
$SCP "admin@$IP:~/tta/manifest.json"   "$OUT/manifest.json"   2>/dev/null || echo "  (no manifest)"
$SCP "admin@$IP:~/tta/acceptance-results.json" "$OUT/acceptance-results.json" 2>/dev/null || echo "  (no acceptance-results — manual battery or pre-1.6.26)"
$SCP "admin@$IP:~/tta/turn_stats.jsonl" "$OUT/turn_stats.jsonl" 2>/dev/null || echo "  (no turn stats — normal for tier A)"
$SCP "admin@$IP:~/tta/run-times.log"   "$OUT/guest-run-times.log" 2>/dev/null || echo "  (no guest timing log)"
$SCP "admin@$IP:~/Desktop/recording.mov" "$OUT/recording.mov" 2>/dev/null || \
$SCP "admin@$IP:~/tta/recording.mov"     "$OUT/recording.mov" 2>/dev/null || echo "  (no recording.mov found — check where QuickTime saved it)"
$SSH "admin@$IP" "claude mcp list 2>&1 | grep -vE '_(KEY|SECRET|TOKEN)='" > "$OUT/tier-surface-proof.txt" 2>/dev/null || true
curl -fsSL https://raw.githubusercontent.com/wikiTaTa/wikitata-test-your-agent/main/tools/run-viewer/index.html -o "$OUT/index.html" \
  || echo "  (viewer download failed — keeping any existing index.html)"
# Safari blocks fetch() over file:// — wrap the manifest as a plain script
# the viewer loads via <script src>, which file:// allows in every browser.
if [ -s "$OUT/manifest.json" ]; then
  { printf 'window.TTA_MANIFEST = '; cat "$OUT/manifest.json"; printf ';\n'; } > "$OUT/manifest.js"
fi

echo "== bundle =="
ls -la "$OUT"
echo
echo "Watch it:  open $OUT/index.html"
