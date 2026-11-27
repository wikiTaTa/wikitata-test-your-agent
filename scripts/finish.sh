#!/bin/bash
# finish.sh — run when the agent DECLARES DONE (recording still rolling).
# The elegant wrap (catMarvin S718): no manual dev-server ask, no Safari ask,
# no Ctrl-C hunt. It:
#   1. stamps agent_done;
#   2. starts the project's dev server (npm run dev, preview fallback) and
#      opens Safari on it, then AUTO-DRIVES the UNIFORM acceptance battery on
#      camera as a user would (accept-drive.mjs; keyboard-first for arithmetic,
#      button-click for scientific) and SCORES it — manual entry only as a
#      fallback when Safari isn't drivable (v1.6.26, catMarvin S721);
#   3. stops the recording, stamps run_end, prints proof + export command
#      (via end-run.sh — ONE wrap path).
# Run it in a NEW Terminal window (Command+N) — Claude Code owns MAIN.
# Escape hatch: TTA_AUTO_ACCEPT=off forces the old manual Return-gated battery.
HARNESS_VERSION="1.6.28"
. "$HOME/tta/run.conf" 2>/dev/null || { PROJECT=calculator; RUN_ID=calc-A-basic-1; }
SHOW_SECS="${TTA_SHOW_SECS:-20}"
tl() { printf '%s\tguest\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$HOME/tta/run-times.log"; }

printf '\033]0;wikiTaTa Test Your Agent : FINISH\007'
# idempotent: the guide can auto-fire this AND the operator can run it — only
# the first instance proceeds (a lock older than 10 min is treated as stale)
LOCK="$HOME/tta/.finish.lock"
if [ -f "$LOCK" ]; then
  AGE=$(( $(date +%s) - $(cat "$LOCK" 2>/dev/null || echo 0) ))
  if [ "$AGE" -ge 0 ] && [ "$AGE" -lt 600 ]; then
    echo ""; echo "  FINISH is already running in another window - nothing to do here."
    exit 0
  fi
fi
date +%s > "$LOCK"
echo ""
printf '\033[1;7;36m ▌ FINISH ▐  wrapping the run \033[0m\n'
echo "  harness v$HARNESS_VERSION - run: $RUN_ID"
echo ""
tl agent_done_finish_started

cd "$HOME/challenge/$PROJECT" 2>/dev/null || { echo "  FAIL: no ~/challenge/$PROJECT — report this."; exit 1; }
URL=""
# The agent's FINAL step (per the startup instruction) should already have
# started the dev server + opened Safari. Reuse a server that's already up
# before starting our own — avoids a port clash and a duplicate Safari tab.
for p in 5173 5174 5175 5176 5177 4173 4174 3000 8080; do
  if curl -fsS -o /dev/null --max-time 1 "http://localhost:$p" 2>/dev/null; then
    URL="http://localhost:$p"; echo "  the app is already running at $URL (agent started it)"; break
  fi
done
if [ -z "$URL" ] && [ -f package.json ] && grep -q '"dev"' package.json; then
  echo "  starting the dev server (npm run dev)..."
  (npm run dev > "$HOME/tta/devserver.log" 2>&1 &)
  sleep 6
  URL=$(grep -o 'http://localhost:[0-9]*' "$HOME/tta/devserver.log" | head -1)
fi
if [ -z "$URL" ] && [ -f package.json ] && grep -q '"preview"' package.json; then
  echo "  no URL from dev - trying npm run preview..."
  (npm run preview > "$HOME/tta/devserver.log" 2>&1 &)
  sleep 5
  URL=$(grep -o 'http://localhost:[0-9]*' "$HOME/tta/devserver.log" | head -1)
fi

if [ -n "$URL" ]; then
  echo "  opening Safari on $URL"
  open -a Safari "$URL"
  tl "app_on_camera $URL"
  SHOWCASE=1
elif [ -f index.html ]; then
  echo "  no dev server found - opening index.html directly"
  open -a Safari "index.html"
  tl app_on_camera_static
  SHOWCASE=1
else
  echo "  WARNING: nothing to open (no dev/preview script, no index.html) - skipping showcase"
  tl finish_no_showcase
  SHOWCASE=0
fi

if [ "$SHOWCASE" = "1" ]; then
  # the UNIFORM acceptance battery — identical for every creation, performed
  # ON CAMERA. Single source of truth = the JSON spec (acceptance/$PROJECT.json);
  # accept-drive.mjs writes acceptance.txt from it (the RUN GUIDE, top right,
  # watches the stamps and renders it PULSING) and, when Safari is drivable,
  # TYPES the battery in as a user would and scores each test.
  SPEC="$HOME/tta/acceptance/$PROJECT.json"
  echo ""
  printf '\033[1;36m ╔════════════════════════════════════════════════════════════╗\033[0m\n'
  printf '\033[1;36m ║   UNIFORM ACCEPTANCE TEST - same battery every run          ║\033[0m\n'
  printf '\033[1;36m ╚════════════════════════════════════════════════════════════╝\033[0m\n'
  tl acceptance_tests_shown
  sleep 3   # let Safari paint the finished app before driving it

  AUTO_ACCEPT="${TTA_AUTO_ACCEPT:-on}"
  DROVE=0
  if [ "$AUTO_ACCEPT" != "off" ] && [ -f "$SPEC" ] && command -v node >/dev/null 2>&1; then
    echo "   auto-driving the battery (keyboard as a user would; scientific by button)..."
    echo ""
    if node "$HOME/tta/accept-drive.mjs" "$SPEC"; then
      DROVE=1
      tl acceptance_auto_done
      RES="$HOME/tta/acceptance-results.json"
      SCORE=$(node -e "try{const r=require('$RES');process.stdout.write(r.passed+'/'+r.total)}catch(e){process.stdout.write('?')}" 2>/dev/null)
      FAILN=$(node -e "try{const r=require('$RES');process.stdout.write(String(r.total-r.passed))}catch(e){process.stdout.write('0')}" 2>/dev/null)
      echo ""
      echo "   auto-run complete - $SCORE passed - results: $RES"
      # LOUD on-fail: a failing battery must be impossible to miss on camera
      # (S721: a silent 1/8 was missed and the recording ended anyway).
      if [ "${FAILN:-0}" != "0" ]; then
        tl "acceptance_battery_FAILED $SCORE"
        printf '\033[1;41;97m\n'
        printf '  ##############################################################\n'
        printf '  #  ACCEPTANCE BATTERY FAILED - %-28s #\n' "$SCORE passed"
        printf '  #  the app did NOT pass every test - do NOT trust this run    #\n'
        printf '  ##############################################################\033[0m\n'
        node -e "try{require('$RES').results.filter(x=>x.status!=='PASS').forEach(x=>console.log('     '+x.id+' '+x.status+'  expected '+x.expect+', got '+x.got))}catch(e){}" 2>/dev/null
        echo ""
      else
        printf '\033[1;42;97m  ✅ ALL %s ACCEPTANCE TESTS PASSED \033[0m\n' "$SCORE"
      fi
    else
      echo ""
      echo "   (auto-drive unavailable - falling back to MANUAL entry)"
      tl acceptance_auto_unavailable
    fi
  fi

  if [ "$DROVE" != "1" ]; then
    # MANUAL fallback — the driver writes acceptance.txt even when it can't drive
    [ -s "$HOME/tta/acceptance.txt" ] || node "$HOME/tta/accept-drive.mjs" "$SPEC" --txt "$HOME/tta/acceptance.txt" >/dev/null 2>&1 || true
    echo "   Key each one into the app; watch the tape record it. Same battery"
    echo "   every run, so runs stay comparable. (RUN GUIDE window shows it too.)"
    echo ""
    sed 's/^/   /' "$HOME/tta/acceptance.txt" 2>/dev/null
    echo ""
    printf '\033[1m   PRESS RETURN here when the tests are done.\033[0m\n'
    read -r || true
  fi
  tl acceptance_tests_done

  # keep recording a clean tail of the finished app before stopping (catMarvin:
  # not a 5s wrap — hold ~20s). Configurable via run.conf TTA_WRAP_HOLD.
  HOLD="${TTA_WRAP_HOLD:-20}"
  printf '\033[1;32m   final capture - recording the finished app for %ss...\033[0m\n' "$HOLD"
  tl "wrap_hold_${HOLD}s"
  sleep "$HOLD"
fi

echo ""
echo "  stopping the recording + finalizing..."
"$HOME/tta/end-run.sh"
