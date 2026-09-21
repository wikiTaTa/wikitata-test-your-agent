#!/bin/bash
# vm-setup.sh — ONE paste inside the VM prepares the whole run.
# Downloads the challenge, starts the stills camera + timing log, brands the
# prompt, installs the run tools (~/tta/*.sh), and docks this window left.
# Usage:  curl -fsSL <raw>/scripts/vm-setup.sh | bash -s [project] [run-id]
set -euo pipefail
HARNESS_VERSION="1.6.28"
PROJECT="${1:-calculator}"
RUN_ID="${2:-calc-A-basic-1}"
RAW="https://raw.githubusercontent.com/wikiTaTa/wikitata-test-your-agent/main"
REL="https://github.com/wikiTaTa/wikitata-test-your-agent/releases/latest/download"

say()  { printf '  %s\n' "$1"; }
tl()   { printf '%s\tguest\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$HOME/tta/run-times.log"; }

mkdir -p "$HOME/tta" "$HOME/challenge"
printf 'PROJECT=%s\nRUN_ID=%s\n' "$PROJECT" "$RUN_ID" > "$HOME/tta/run.conf"
tl "guest_setup_start v$HARNESS_VERSION"

say "branding the prompt (new windows show it)..."
echo admin | sudo -S scutil --set HostName wikiTaTa-TestYourAgent-VirtualMacTest 2>/dev/null || true

say "downloading the $PROJECT starter..."
curl -fsSL "$REL/${PROJECT}-starter.zip" -o "$HOME/${PROJECT}-starter.zip"
unzip -q -o "$HOME/${PROJECT}-starter.zip" -d "$HOME/challenge"
tl starter_unpacked

say "installing run tools into ~/tta ..."
for s in capture-stills.sh record-screen.sh run-guide.sh start-recording.sh open-guide.sh end-run.sh begin.sh finish.sh accept-drive.mjs wikiTaTa-Recording.terminal; do
  curl -fsSL "$RAW/scripts/$s" -o "$HOME/tta/$s"
done
# machine-readable acceptance battery (single source; accept-drive.mjs reads it)
mkdir -p "$HOME/tta/acceptance"
curl -fsSL "$RAW/scripts/acceptance/${PROJECT}.json" -o "$HOME/tta/acceptance/${PROJECT}.json" 2>/dev/null || \
  say "  (no acceptance spec for $PROJECT — finish will use manual entry)"
curl -fsSL "$RAW/instructions/${PROJECT}.txt" -o "$HOME/tta/startup-instruction.txt"
chmod +x "$HOME"/tta/*.sh 2>/dev/null || true

# Let finish.sh AUTO-DRIVE the acceptance battery in Safari via `do JavaScript`
# (v1.6.26). Needs the Safari pref below AND a one-time Terminal->Safari
# Automation approval — the latter is granted once on the GOLDEN image so every
# clone inherits it (see RUNBOOK golden-image prep). If either is missing,
# accept-drive.mjs exits 2 and finish.sh falls back to manual entry.
say "enabling Safari JavaScript-from-Apple-Events (for the auto acceptance run)..."
defaults write com.apple.Safari IncludeDevelopMenu -bool true 2>/dev/null || true
defaults write com.apple.Safari AllowJavaScriptFromAppleEvents -bool true 2>/dev/null || true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool true 2>/dev/null || true
# tl = timing-log stamper as a REAL script (works from any window/shell)
printf '#!/bin/bash\nprintf "%%s\\tguest\\t%%s\\n" "$(date -u +%%Y-%%m-%%dT%%H:%%M:%%SZ)" "$*" >> "$HOME/tta/run-times.log"\n' > "$HOME/tta/tl"
chmod +x "$HOME/tta/tl"

say "pre-trusting the challenge folder (no trust dialog at agent launch)..."
if [ ! -f "$HOME/.claude.json" ]; then
  printf '{"projects":{"%s":{"hasTrustDialogAccepted":true}}}\n' "$HOME/challenge/$PROJECT" > "$HOME/.claude.json"
else
  python3 - "$HOME/.claude.json" "$HOME/challenge/$PROJECT" <<'PYEOF' || say "  (could not merge trust flag - the trust dialog may appear once)"
import json, sys
p, proj = sys.argv[1], sys.argv[2]
d = json.load(open(p))
d.setdefault("projects", {}).setdefault(proj, {})["hasTrustDialogAccepted"] = True
json.dump(d, open(p, "w"))
PYEOF
fi

say "starting the stills camera (1 photo / 30s)..."
{ RUN_ID="$RUN_ID" INTERVAL=10 "$HOME/tta/capture-stills.sh" > "$HOME/tta/stills.log" 2>&1 & }
tl stills_started

# dock this window left (best-effort; cosmetic only)
osascript -e 'tell application "Finder" to set db to bounds of window of desktop' \
  -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' \
  -e 'tell application "Terminal" to set font size of selected tab of front window to 16' \
  -e 'tell application "Terminal" to set bounds of front window to {0, 25, sw * 27 div 50, sh - 80}' \
  >/dev/null 2>&1 || true

echo
say "READY — harness v$HARNESS_VERSION"
say "NEXT:  ~/tta/begin.sh   (it walks you through everything, Return by Return)"
