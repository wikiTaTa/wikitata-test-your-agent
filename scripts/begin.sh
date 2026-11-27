#!/bin/bash
# begin.sh — the guided run wizard. Run this ONE command in a fresh VM
# Terminal window. It PAGES like an installer: every screen is repainted
# fresh (block-graphic header + colored step tracker + ONE pulsing
# highlighter "PRESS RETURN" action) — the operator never sees a scrollback
# wall, and the recording only ever shows the current step.
HARNESS_VERSION="1.6.28"
. "$HOME/tta/run.conf" 2>/dev/null || { PROJECT=calculator; RUN_ID=calc-A-basic-1; }
ATTNF="$HOME/tta/attention"
export LANG="${LANG:-en_US.UTF-8}"

apply_theme() { # apply a stock macOS Terminal profile to the FRONT window,
  # then RE-ASSERT our font size + bounds (profiles carry their own fonts —
  # letting one land would reflow the window and shred absolute-row paints)
  [ -n "$1" ] || return 0
  osascript -e "tell application \"Terminal\" to set current settings of front window to settings set \"$1\"" >/dev/null 2>&1 || true
  osascript -e 'tell application "Finder" to set db to bounds of window of desktop' \
    -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' \
    -e 'tell application "Terminal" to set font size of selected tab of front window to 16' \
    -e 'tell application "Terminal" to set bounds of front window to {0, 25, sw * 27 div 50, sh - 80}' \
    >/dev/null 2>&1 || true
}

focus_main() {
  osascript -e 'tell application "Terminal" to activate' \
    -e 'tell application "Terminal" to set index of (first window whose name contains "MAIN") to 1' \
    >/dev/null 2>&1 || true
}
printf '\033]0;wikiTaTa Test Your Agent : MAIN — type here\007'
# MAIN owns the LEFT 54% of the screen; guide top-right, recording bottom-right.
osascript -e 'tell application "Finder" to set db to bounds of window of desktop' \
  -e 'set sw to item 3 of db' -e 'set sh to item 4 of db' \
  -e 'tell application "Terminal" to set font size of selected tab of front window to 16' \
  -e 'tell application "Terminal" to set bounds of front window to {0, 25, sw * 27 div 50, sh - 80}' \
  >/dev/null 2>&1 || true

ROW=1
PULSER=""
say()  { printf '%s\n' "$1"; ROW=$((ROW+1)); }
bold() { printf '\033[1m%s\033[0m\n' "$1"; ROW=$((ROW+1)); }
cy()   { printf '\033[1;36m%s\033[0m\n' "$1"; ROW=$((ROW+1)); }
grn()  { printf '\033[1;32m%s\033[0m\n' "$1"; ROW=$((ROW+1)); }
hl()   { printf '\033[1;30;43m%s\033[0m\n' "$1"; ROW=$((ROW+1)); }

page_top() { # $1 = current step 1..4 (0 = welcome page, no tracker)
  printf '\033[2J\033[H'; ROW=1
  # while the wizard is asking, the MAIN window owns the suite's ONE pulse
  mkdir -p "$HOME/tta"; echo main > "$ATTNF"
  printf '\033[1;7;36m ▌ MAIN WINDOW ▐  this is where you type \033[0m\n'; ROW=$((ROW+1))
  cy  " ╔══════════════════════════════════════════════════════════════════╗"
  cy  " ║   wikiTaTa \"Test Your Agent\" ▪ guided run wizard                  ║"
  cy  " ╚══════════════════════════════════════════════════════════════════╝"
  say ""
  say "   run: $RUN_ID  ·  harness v$HARNESS_VERSION"
  say ""
  if [ "$1" -gt 0 ]; then
    local i=1 name
    for name in "stills camera (one photo every 10s)" \
                "screen recording of the whole run" \
                "run guide + instruction on the clipboard" \
                "launch the agent (Claude Code)"; do
      if [ "$i" -lt "$1" ]; then grn "     ✔ STEP $i  $name"
      elif [ "$i" -eq "$1" ]; then hl "     ▶ STEP $i  $name "
      else say "     ▷ STEP $i  $name"; fi
      i=$((i+1))
    done
    say ""
  fi
}

press_return() { # $1 pulses (~1s highlighter <-> bold) until Return; $2.. below
  local first="$1"; shift
  local prow=$((ROW+1)) extra
  say ""
  say " $first"
  for extra in "$@"; do say "   $extra"; done
  say ""
  ( while :; do
      printf '\033[%d;1H\033[2K\033[1;30;43m %s\033[0m' "$prow" "$first"; sleep 0.9
      printf '\033[%d;1H\033[2K\033[1m %s\033[0m'       "$prow" "$first"; sleep 0.9
    done ) 2>/dev/null &
  PULSER=$!
  printf '\033[%d;1H' "$ROW"
  if ! read -rs; then
    kill "$PULSER" 2>/dev/null; printf '\033[?25h\033[0m\n'; exit 1
  fi
  kill "$PULSER" 2>/dev/null; wait "$PULSER" 2>/dev/null
  printf '\033[%d;1H\033[2K\033[1;32m ✔%s\033[0m' "$prow" "${first#?}"
  printf '\033[%d;1H' "$ROW"
}

printf '\033[?25l'
trap 'printf "\033[?25h\033[0m"; [ -n "$PULSER" ] && kill "$PULSER" 2>/dev/null' EXIT

# ---- import our custom recording profile (built for the video: dark,
# every ANSI slot above the contrast floor, incl. the dim grey Claude Code
# uses). Import = open the .terminal file once (spawns a stray window we
# close), then it is selectable like any stock profile.
rec_profile_name() { # the profile's ACTUAL imported name (Terminal names it
  # after the FILE -> "wikiTaTa-Recording", not the plist's "wikiTaTa
  # Recording"). Resolve it live so apply never silently no-ops on the mismatch.
  osascript -e 'tell application "Terminal" to get name of every settings set' 2>/dev/null \
    | tr ',' '\n' | sed 's/^ *//' | grep -i 'wikiTaTa.*Recording' | head -1
}
REC_NAME=""
ensure_recording_profile() {
  [ -f "$HOME/tta/wikiTaTa-Recording.terminal" ] || return 1
  REC_NAME="$(rec_profile_name)"
  if [ -z "$REC_NAME" ]; then
    open "$HOME/tta/wikiTaTa-Recording.terminal"
    sleep 1.2
    osascript -e 'tell application "Terminal" to close front window' >/dev/null 2>&1 || true
    focus_main
    REC_NAME="$(rec_profile_name)"
  fi
  [ -n "$REC_NAME" ]
}

# ---- PAGE: welcome + color scheme (repainted WHOLE after every try —
# applying a profile can reflow the window, so single-row patching is unsafe:
# it left duplicate status lines on catMarvin's screen)
theme_page() { # $1 = status line ("" = none yet)
  page_top 0
  cy  "   █     █ ██████ █       █████  ████  █     █ ██████"
  cy  "   █     █ █      █      █      █    █ ██   ██ █"
  cy  "   █  █  █ █████  █      █      █    █ █ █ █ █ █████"
  cy  "   █ █ █ █ █      █      █      █    █ █  █  █ █"
  cy  "    █   █  ██████ ██████  █████  ████  █     █ ██████"
  say ""
  bold "   ...to the wikiTaTa \"Test Your Agent\" testing suite."
  say ""
  bold "   FIRST - pick a color scheme for these windows."
  say  "   You are already looking at our recommendation:"
  say ""
  grn "     0  wikiTaTa Recording  << RECOMMENDED - built for the video"
  say ""
  say "     1  Basic (light)          6  Novel (light)"
  say "     2  Homebrew (green/black) 7  Red Sands"
  say "     3  Pro (white/black)      8  Grass"
  say "     4  Ocean (blue)           9  Silver Aerogel (light)"
  say "     5  Man Page (light)"
  say ""
  bold "   TYPE a number to TRY a theme - it applies INSTANTLY so you can"
  bold "   see it. Try as many as you like; press Return to KEEP the one"
  bold "   you are looking at."
  say ""
  [ -n "$1" ] && grn "$1"
}
THEME=""
if ensure_recording_profile; then
  THEME="$REC_NAME"          # the real imported name (hyphen), so apply STICKS
  apply_theme "$THEME"
fi
theme_page ""
while :; do
  read -rsn1 CH || { printf '\033[?25h\033[0m\n'; exit 1; }
  case "$CH" in
    0) T2="${REC_NAME:-wikiTaTa-Recording}";;
    1) T2="Basic";;      2) T2="Homebrew";;  3) T2="Pro";;
    4) T2="Ocean";;      5) T2="Man Page";;  6) T2="Novel";;
    7) T2="Red Sands";;  8) T2="Grass";;     9) T2="Silver Aerogel";;
    "") break;;
    *) T2="";;
  esac
  if [ -n "$T2" ]; then
    THEME="$T2"
    apply_theme "$THEME"
    theme_page "   ✔ now showing: $THEME — Return to KEEP it, or try another number"
  fi
done
printf "THEME='%s'\n" "$THEME" > "$HOME/tta/theme.conf"
theme_page "   ✔ color scheme locked: ${THEME:-default} (the other windows will match)"
sleep 1

# ---- PAGE: what this wizard does ----
page_top 0
say "   This wizard prepares and records your test run, then launches"
say "   the agent. It moves ONE page at a time, and each page asks for"
say "   exactly ONE thing: when the pulsing highlighter says PRESS"
say "   RETURN, you press the Return key. That is it."
say ""
say "   What it sets up, in order:"
say "     1. stills camera - one PNG of the screen every 10 seconds"
say "        (these become the flip-book replay of your run);"
say "     2. screen recording - a movie of the ENTIRE screen"
say "        (a clock window shows you it is live);"
say "     3. run guide - opens top right and loads your one startup"
say "        instruction onto the clipboard;"
say "     4. the agent itself - Claude Code launches right here."
press_return "▶▶ PRESS RETURN to begin ◀◀"

# ---- STEP 1: stills camera (automatic; fresh capture state on re-run) ----
pkill -f capture-stills.sh 2>/dev/null; pkill -INT -x screencapture 2>/dev/null; sleep 1
# a PRIOR run's leftovers would pollute THIS run — rotate them aside (never
# delete: they are evidence). Stamps fast-forward the self-advancing guide;
# stale stills glob into the new flip-book manifest; recording.mov is the
# prior movie.
NOWS=$(date +%s)
if grep -q -e claude_launch -e run_end "$HOME/tta/run-times.log" 2>/dev/null; then
  mv "$HOME/tta/run-times.log" "$HOME/tta/run-times.prev.$NOWS.log"
fi
if [ -n "$(ls "$HOME/tta/stills/" 2>/dev/null)" ]; then
  mv "$HOME/tta/stills" "$HOME/tta/stills.prev.$NOWS"
  rm -f "$HOME/tta/manifest.json"
fi
[ -s "$HOME/tta/recording.mov" ] && mv "$HOME/tta/recording.mov" "$HOME/tta/recording.prev.$NOWS.mov"
{ RUN_ID="$RUN_ID" INTERVAL=10 "$HOME/tta/capture-stills.sh" > "$HOME/tta/stills.log" 2>&1 & }
"$HOME/tta/tl" stills_started

# ---- PAGE: step 2, screen recording ----
page_top 2
grn "   STEP 1 needed nothing from you - the stills camera is already"
grn "   rolling (one photo of the screen every 10 seconds)."
press_return "▶▶ PRESS RETURN - this will START THE SCREEN RECORDING ◀◀" \
             "A clock window opens bottom right; the whole screen records" \
             "until the end of the run."
"$HOME/tta/start-recording.sh" >/dev/null
until pgrep -x screencapture >/dev/null; do
  page_top 2
  bold "   The recording did NOT start - macOS is asking for permission."
  say  ""
  say  "   Approve the Screen Recording permission (password: admin),"
  say  "   let Terminal quit and reopen if it asks, then come back here."
  press_return "▶▶ PRESS RETURN to try the recording again ◀◀"
  "$HOME/tta/start-recording.sh" >/dev/null
done
focus_main

# ---- PAGE: step 3, run guide + clipboard ----
page_top 3
grn "   STEP 2 DONE - the screen recording is LIVE (see the clock"
grn "   window, bottom right)."
press_return "▶▶ PRESS RETURN - this will OPEN THE RUN GUIDE window ◀◀" \
             "It docks top right and puts the startup instruction on the" \
             "clipboard, ready to paste."
"$HOME/tta/open-guide.sh" >/dev/null 2>&1
focus_main

# ---- PAGE: step 4, launch the agent ----
page_top 4
grn "   STEP 3 DONE - the guide is up (top right); your instruction is"
grn "   ON THE CLIPBOARD."
say ""
say "   Next, the agent (Claude Code) launches RIGHT HERE. When it"
say "   opens: press Command+V, then Return."
bold "   ▶▶ THAT Return starts the clock. BASIC persona from then on. ◀◀"
say ""
say "   NOTE: permissions are PRE-APPROVED for this sandbox (the agent"
say "   runs with skip-permissions and will never stop to ask - that is"
say "   the point of the test: we open it up and just let it GO)."
press_return "▶▶ PRESS RETURN - this will LAUNCH THE AGENT (Claude Code) ◀◀"
printf '\033[?25h\033[0m\033[2J\033[H'
# Claude Code owns this window from here — hand the suite's ONE pulse to the guide
echo guide > "$ATTNF"
# sync Claude Code's OWN theme to the terminal background so its text is
# never dark-theme grey on a light window (or vice versa) in the recording
case "$THEME" in
  wikiTaTa*Recording|Homebrew|Pro|Ocean|"Red Sands"|Grass) CLAUDE_THEME=dark;;
  *) CLAUDE_THEME=light;;
esac
claude config set -g theme "$CLAUDE_THEME" >/dev/null 2>&1 || true
# ring the terminal bell whenever Claude needs input — our recording profile
# renders it as a VISUAL screen flash (no sound; screenshare-proof)
claude config set -g preferredNotifChannel terminal_bell >/dev/null 2>&1 || true
# PERMISSIONS policy (run.conf, default auto): auto = --dangerously-skip-
# permissions — the sanctioned mode for disposable sandbox VMs; kills every
# approve/don't-ask-again tap so operator latency measures ANSWERS, not
# clicking. Recorded in the timing log for run-comparability evidence.
PERMISSIONS="${PERMISSIONS:-auto}"
if [ "$PERMISSIONS" = "auto" ]; then
  "$HOME/tta/tl" "claude_launch mode=skip-permissions"
  cd "$HOME/challenge/$PROJECT" && exec claude --dangerously-skip-permissions
else
  "$HOME/tta/tl" "claude_launch mode=ask-permissions"
  cd "$HOME/challenge/$PROJECT" && exec claude
fi
