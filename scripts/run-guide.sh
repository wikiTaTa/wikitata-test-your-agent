#!/bin/bash
# run-guide.sh — the LIVE run guide. Runs in its own Terminal window (opened
# by open-guide.sh, docked top-right). The operator NEVER types here: the
# window paints ONE panel at a time — only what to do RIGHT NOW — and
# advances ITSELF by watching the run's real signals:
#
#   LAUNCH   waiting for the claude_launch stamp in ~/tta/run-times.log
#   PASTE    Claude Code is up; waiting for agent transcript activity
#            (the operator's paste + Return) under ~/.claude/projects
#   LIVE     the run is timed; persona reference card stays up
#   WRAP-UP  the screen recording stopped -> show the end-run step
#   DONE     run_end stamped -> export instructions
#
# ASCII-ENHANCED: block-graphic frames (═ ║ ╔ ╝), ANSI color (cyan structure,
# green done, highlighter-yellow action). The "DO THIS NOW" box PULSES gently
# (~1s highlighter-on <-> bold, no fast blink). Painting is absolute-
# positioned; lines are sliced to the window width CHARACTER-wise (block
# glyphs are multibyte), so scrolling soup is impossible at any size.
#
# Unchanged duties: puts the startup instruction ON THE CLIPBOARD and stamps
# guide_opened_clipboard_loaded into the timing log.
#
# Usage: run-guide.sh [project] [run-id]   (defaults: calculator, calc-A-basic-1)
HARNESS_VERSION="1.6.28"
SELF_SHA=$(shasum "$0" 2>/dev/null | cut -c1-8)
PROJECT="${1:-calculator}"
RUN_ID="${2:-calc-A-basic-1}"
RAW="https://raw.githubusercontent.com/wikiTaTa/wikitata-test-your-agent/main"
INSTR="$HOME/tta/startup-instruction.txt"
TLOG="$HOME/tta/run-times.log"
MARK="$HOME/tta/.claude-launch.marker"
ATTNF="$HOME/tta/attention"
CAP_SECS="${TTA_CAP_SECS:-2700}"   # 45:00 — at the cap, attention jumps to the recording window
export LANG="${LANG:-en_US.UTF-8}"

mkdir -p "$HOME/tta"
# offline-first: vm-setup already staged the instruction; network is a fallback only
if [ ! -s "$INSTR" ]; then
  if ! curl -fsSL "$RAW/instructions/${PROJECT}.txt" -o "$INSTR"; then
    echo "FAIL: instruction not staged and download failed (check the VM's network) — report this."
    exit 1
  fi
fi
pbcopy < "$INSTR" || { echo "FAIL: could not load the clipboard — report this."; exit 1; }
printf '%s\tguest\tguide_opened_clipboard_loaded\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$TLOG"

printf '\033]0;wikiTaTa Test Your Agent : RUN GUIDE — do what pulses\007'
printf '\033[?25l'
trap 'printf "\033[?25h\033[0m"; exit 0' INT TERM

rm -f "$MARK"
STATE=launch
LIVE_AT=0
TICK=0
# AUTO-FINISH: the guide watches the transcript; when it stops growing for
# IDLE_DONE seconds (agent done in a skip-permissions run), the guide FIRES
# ~/tta/finish.sh itself — no manual Command+N. run.conf can disable it
# (AUTO_FINISH=off) or retune the idle window (TTA_IDLE_DONE).
. "$HOME/tta/run.conf" 2>/dev/null || true
AUTO_FINISH="${AUTO_FINISH:-on}"
IDLE_DONE="${TTA_IDLE_DONE:-180}"    # transcript quiet this long = agent done
MIN_RUN=90                            # never auto-fire in the first 90s
LAST_BYTES=0
IDLE_SINCE=0
AUTOFIRED=0
IDLE_SECS=0
# operator can wrap the run with a single 'C' keypress (no Ctrl-C hunt).
# macOS bash 3.2 has NO fractional `read -t`, so we cannot poll the key inline
# without wrecking the 0.3s paint cadence. Instead a BACKGROUND reader blocks on
# the tty and, on 'C', drops a sentinel file the paint loop polls each tick.
HAVE_TTY=0; [ -r /dev/tty ] && HAVE_TTY=1
WRAPFLAG="$HOME/tta/.wrap-now"; rm -f "$WRAPFLAG"
KEYPID=''
fire_finish() { # $1 = timing-log event tag
  [ "$AUTOFIRED" -eq 0 ] || return 0
  AUTOFIRED=1
  printf '%s\tguest\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$TLOG"
  osascript -e 'tell application "Terminal" to do script "~/tta/finish.sh"' >/dev/null 2>&1 || true
}
if [ "$HAVE_TTY" -eq 1 ]; then
  ( stty -echo -icanon min 1 time 0 </dev/tty 2>/dev/null || exit 0
    while IFS= read -r -n 1 ch 2>/dev/null; do
      case "$ch" in c|C) : > "$WRAPFLAG"; break;; esac
    done ) </dev/tty &
  KEYPID=$!
fi
trap 'stty sane </dev/tty 2>/dev/null; [ -n "$KEYPID" ] && kill "$KEYPID" 2>/dev/null; printf "\033[?25h\033[0m"; exit 0' INT TERM

# Panel line queue. Attributes:
#   n normal · b bold · c cyan-bold (structure) · g green-bold (done/live-ok)
#   r red-bold · k label chip (cyan reverse) · h steady highlighter
#   p pulsing highlighter (yellow) · q pulsing highlighter (green)
# SINGLE-PULSE DISCIPLINE: p/q actually pulse ONLY while ~/tta/attention says
# "guide" (or the file is absent — manual fallback); otherwise they render
# steady, because exactly one window in the suite pulses at a time.
L()  { LINES[${#LINES[@]}]="$1"; ATTRS[${#ATTRS[@]}]=n; }
BL() { LINES[${#LINES[@]}]="$1"; ATTRS[${#ATTRS[@]}]=b; }
CL() { LINES[${#LINES[@]}]="$1"; ATTRS[${#ATTRS[@]}]=c; }
GL() { LINES[${#LINES[@]}]="$1"; ATTRS[${#ATTRS[@]}]=g; }
RL() { LINES[${#LINES[@]}]="$1"; ATTRS[${#ATTRS[@]}]=r; }
KL() { LINES[${#LINES[@]}]="$1"; ATTRS[${#ATTRS[@]}]=k; }
HL() { LINES[${#LINES[@]}]="$1"; ATTRS[${#ATTRS[@]}]=h; }
PL() { LINES[${#LINES[@]}]="$1"; ATTRS[${#ATTRS[@]}]=p; }
QL() { LINES[${#LINES[@]}]="$1"; ATTRS[${#ATTRS[@]}]=q; }

header() { # $1 = current phase 1..4 for the tracker
  local i=1 name
  KL " ▌ RUN GUIDE ▐  read me — you never type here "
  CL " ╔══════════════════════════════════════════════════════════════╗"
  CL " ║   wikiTaTa TEST YOUR AGENT ▪ RUN GUIDE                        ║"
  CL " ╚══════════════════════════════════════════════════════════════╝"
  L  "   run: $RUN_ID  ·  harness v$HARNESS_VERSION ($SELF_SHA)"
  L ""
  for name in "LAUNCH THE AGENT" "PASTE THE INSTRUCTION" "LIVE RUN (persona: BASIC)" "WRAP-UP"; do
    if [ "$i" -lt "$1" ]; then GL "     ✔ $name"
    elif [ "$i" -eq "$1" ]; then HL "     ▶ $name "
    else L "     ▷ $name"; fi
    i=$((i+1))
  done
  L ""
}

while :; do
  TICK=$((TICK+1))
  P=$(( (TICK / 3) % 2 ))                       # gentle pulse: ~0.9s per half
  COLS=$(tput cols 2>/dev/null); [ -n "$COLS" ] || COLS=80
  ROWS=$(tput lines 2>/dev/null); [ -n "$ROWS" ] || ROWS=24

  # ---- advance the state machine from the run's real signals ----
  if grep -q "run_end" "$TLOG" 2>/dev/null; then
    if [ "$STATE" != "done" ]; then STATE=done; echo guide > "$ATTNF"; fi
  elif grep -q "agent_done_finish_started" "$TLOG" 2>/dev/null; then
    # the agent declared done and finish.sh is running — the guide takes
    # over the prompting (Todd: claude's final step triggers MORE guidance)
    if [ "$STATE" != "finish" ]; then STATE=finish; echo guide > "$ATTNF"; fi
  else
    case "$STATE" in
      launch)
        if grep -q "claude_launch" "$TLOG" 2>/dev/null; then
          touch "$MARK"; STATE=paste; echo guide > "$ATTNF"
        fi;;
      paste)
        if [ -d "$HOME/.claude/projects" ] && \
           [ -n "$(find "$HOME/.claude/projects" -name '*.jsonl' -newer "$MARK" -size +4k 2>/dev/null | head -1)" ]; then
          STATE=live; LIVE_AT=$(date +%s)
          printf '%s\tguest\trun_live_detected\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$TLOG"
        fi;;
      live)
        # 45:00 cap: fire the cross-window trigger ONCE — the recording
        # window starts pulsing CLICK HERE / Ctrl-C, this guide goes steady
        if [ "$LIVE_AT" -gt 0 ] && [ $(( $(date +%s) - LIVE_AT )) -ge "$CAP_SECS" ] && \
           [ "$(cat "$ATTNF" 2>/dev/null)" != "recording" ]; then
          echo recording > "$ATTNF"
          printf '%s\tguest\tcap_reached_attention_to_recording\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$TLOG"
        fi
        # transcript-idle detector (every ~2s): bytes stop growing => agent
        # done. IDLE_SECS drives a visible countdown; at IDLE_DONE, fire finish.
        if [ $(( TICK % 6 )) -eq 0 ]; then
          NB=$(cat "$HOME"/.claude/projects/*/*.jsonl 2>/dev/null | wc -c | tr -d ' '); [ -n "$NB" ] || NB=0
          if [ "$NB" -gt "$LAST_BYTES" ]; then LAST_BYTES=$NB; IDLE_SINCE=$(date +%s); fi
          [ "$IDLE_SINCE" -eq 0 ] && IDLE_SINCE=$(date +%s)
          IDLE_SECS=$(( $(date +%s) - IDLE_SINCE ))
        fi
        ELAPSED=$(( $(date +%s) - LIVE_AT ))
        if [ "$AUTO_FINISH" = "on" ] && [ "$AUTOFIRED" -eq 0 ] && \
           [ "$ELAPSED" -ge "$MIN_RUN" ] && [ "$IDLE_SECS" -ge "$IDLE_DONE" ]; then
          fire_finish guide_autofired_finish
        fi
        if ! pgrep -x screencapture >/dev/null 2>&1; then
          STATE=wrapup; echo guide > "$ATTNF"
          printf '%s\tguest\tguide_saw_recording_stop\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$TLOG"
        fi;;
    esac
  fi
  ATTN=$(cat "$ATTNF" 2>/dev/null)

  # ---- build the current panel ----
  LINES=(); ATTRS=()
  case "$STATE" in
    launch)
      header 1
      BL "  WHAT IS HAPPENING NOW"
      L  "    Your startup instruction is already ON THE CLIPBOARD of"
      L  "    this Mac. (It is the only steering you ever give the agent.)"
      L  "    The wizard in the MAIN window (left) is ready to launch"
      L  "    Claude Code - the agent you are testing."
      L  ""
      PL "  ╔══════════════════════════════════════════════════════════╗"
      PL "  ║  DO THIS NOW:  go to the MAIN window and PRESS RETURN     ║"
      PL "  ╚══════════════════════════════════════════════════════════╝"
      L  ""
      L  "    That Return launches the agent. No login is needed."
      L  "    This guide notices by itself and shows your next move."
      L  ""
      L  "    (Fallback, only if the wizard is not running:"
      L  "      ~/tta/tl claude_launch; cd ~/challenge/$PROJECT && claude )"
      ;;
    paste)
      header 2
      BL "  WHAT IS HAPPENING NOW"
      L  "    Claude Code is starting in the MAIN window (left)."
      L  ""
      PL "  ╔══════════════════════════════════════════════════════════╗"
      PL "  ║  DO THIS NOW:  click into Claude Code, press Command+V,  ║"
      PL "  ║                then press Return.                        ║"
      PL "  ╚══════════════════════════════════════════════════════════╝"
      L  ""
      BL "    The moment you press Return, the run is LIVE and timed."
      L  ""
      L  "    Clipboard got overwritten? Reload it any time with:"
      L  "      pbcopy < ~/tta/startup-instruction.txt"
      ;;
    live)
      S=$(( $(date +%s) - LIVE_AT ))
      ET="$(printf %02d $((S/60))):$(printf %02d $((S%60)))"
      header 3
      if [ "$S" -ge "$CAP_SECS" ]; then
        RL "  ▶▶ 45:00 CAP REACHED at $ET - STOP THE RUN NOW ◀◀"
        RL "     the SCREEN RECORDING window (bottom right) is pulsing:"
        RL "     click it and press Ctrl-C."
      else
        QL "  ▶▶ THE RUN IS LIVE - elapsed $ET - your persona: BASIC ◀◀ "
      fi
      L  ""
      BL "  WHAT IS HAPPENING NOW"
      L  "    Claude is building the calculator in the MAIN window (left)."
      L  "    You are the BASIC persona: a non-technical user watching. The"
      L  "    timer above is the run clock. This guide moves itself along."
      L  ""
      BL "  YOUR ONLY MOVES WHILE THE RUN IS LIVE:"
      L  "    ▪ Agent asks a question?   Shortest sensible answer."
      L  "    ▪ Permission prompt?       Approve it. (Runs normally"
      L  "      auto-approve these - seeing one at all is rare.)"
      L  "    ▪ NEVER suggest features, tools, designs, or approaches."
      L  "    ▪ Agent idle ~60s with no question?  Type exactly:  continue"
      L  "    ▪ Jot down anything you type, with a rough time."
      L  ""
      L  "  HOW THE RUN ENDS (no Ctrl-C, ever):"
      L  "    Claude's LAST step is to start the app and open it in Safari,"
      L  "    then say it is DONE. When you see that -"
      QL "  ▶▶ press  C  here  =  \"Claude is done, wrap it up\" ◀◀"
      L  "     That stops the recording, auto-tests the app in Safari,"
      L  "     and prints the export command. One key. That is it."
      if [ "$AUTO_FINISH" = "on" ]; then
        RE=$(( IDLE_DONE - IDLE_SECS ))
        if [ "$IDLE_SECS" -ge 20 ] && [ "$RE" -gt 0 ] && [ $(( $(date +%s) - LIVE_AT )) -ge "$MIN_RUN" ]; then
          QL "  ▶▶ agent looks DONE - auto-wrapping in ${RE}s (or press C now) ◀◀"
        else
          L  ""
          L  "    (If you miss it, the guide also auto-wraps once the agent"
          L  "     goes quiet ~${IDLE_DONE}s. Either way: no Command+N, no Ctrl-C.)"
        fi
      fi
      TKB=$(du -sk "$HOME/.claude/projects" 2>/dev/null | awk '{print $1}')
      L  ""
      if [ "$IDLE_SECS" -ge 20 ]; then
        L  "  ● transcript ${TKB:-0} KB - quiet ${IDLE_SECS}s"
      else
        GL "  ● heartbeat: agent transcript ${TKB:-0} KB and growing"
      fi
      ;;
    finish)
      header 4
      BL "  WHAT IS HAPPENING NOW"
      L  "    The agent is DONE - the FINISH script is wrapping the run:"
      L  "    dev server starting, Safari opening the finished app."
      L  ""
      if grep -q "acceptance_tests_shown" "$TLOG" 2>/dev/null && [ -s "$HOME/tta/acceptance.txt" ]; then
        if grep -q "acceptance_auto_unavailable" "$TLOG" 2>/dev/null; then
          PL "  ▶▶ KEY THESE INTO THE APP NOW - same battery every run ◀◀"
        else
          PL "  ▶▶ ACCEPTANCE BATTERY - typing itself into the app (auto) ◀◀"
        fi
        L  ""
        while IFS= read -r tln; do L "     $tln"; done < "$HOME/tta/acceptance.txt"
        L  ""
        if grep -q "acceptance_auto_unavailable" "$TLOG" 2>/dev/null; then
          BL "    Done with all 8? Press Return in the FINISH window -"
          BL "    the recording stops and everything finalizes."
        else
          BL "    Watch it run - each test is keyed in and scored, then the"
          BL "    recording holds ~20s and finalizes. No typing needed."
        fi
      else
        L  "    The uniform acceptance battery will appear RIGHT HERE"
        L  "    in a moment - it types itself into the app on camera."
      fi
      ;;
    wrapup)
      header 4
      BL "  WHAT IS HAPPENING NOW"
      L  "    The screen recording has stopped."
      L  ""
      PL "  ╔══════════════════════════════════════════════════════════╗"
      PL "  ║  DO THIS NOW:  open a NEW Terminal window (Command+N)    ║"
      PL "  ║                and run:   ~/tta/end-run.sh               ║"
      PL "  ╚══════════════════════════════════════════════════════════╝"
      L  ""
      L  "    That stamps the end time, finalizes the recording file,"
      L  "    and prints the proof + the export command."
      ;;
    done)
      header 4
      GL "  ✔ ALL DONE - THE RUN IS COMPLETE"
      L  ""
      RKB=$(du -sk "$HOME/tta/recording.mov" 2>/dev/null | awk '{print $1}')
      NST=$(ls "$HOME/tta/stills" 2>/dev/null | wc -l | tr -d ' ')
      L  "    Captured: recording $(( ${RKB:-0} / 1024 )) MB · ${NST:-0} stills"
      L  "    (the end time is stamped; the recording is finalized)."
      L  ""
      L  "    Next, on the VM HOST (not inside this VM):"
      BL "      cd ~/tta-runs/staging && ./export-run.sh run-$RUN_ID $RUN_ID"
      L  ""
      L  "    You can close this window."
      ;;
  esac

  # ---- paint: absolute-position every line, char-wise slice, no newlines ----
  row=1
  i=0
  while [ "$i" -lt "${#LINES[@]}" ]; do
    [ "$row" -gt "$ROWS" ] && break
    line="${LINES[$i]}"
    line="${line:0:$COLS}"
    # pulse only while this window owns the attention token (or no wizard)
    PULSE_OK=0
    if [ -z "$ATTN" ] || [ "$ATTN" = "guide" ]; then PULSE_OK=1; fi
    case "${ATTRS[$i]}" in
      c) A='\033[1;36m';;
      g) A='\033[1;32m';;
      r) A='\033[1;31m';;
      k) A='\033[1;7;36m';;
      h) A='\033[1;30;43m';;
      p) if [ "$PULSE_OK" -eq 1 ] && [ "$P" -eq 1 ]; then A='\033[1;30;43m'; else A='\033[1m'; fi;;
      q) if [ "$PULSE_OK" -eq 1 ] && [ "$P" -eq 1 ]; then A='\033[1;30;42m'; else A='\033[1;32m'; fi;;
      b) A='\033[1m';;
      *) A='';;
    esac
    printf '\033[%d;1H\033[2K'"$A"'%s\033[0m' "$row" "$line"
    row=$((row+1))
    i=$((i+1))
  done
  [ "$row" -le "$ROWS" ] && printf '\033[%d;1H\033[J' "$row"

  # ---- pace the loop; the bg reader drops WRAPFLAG when 'C' is pressed ----
  sleep 0.3
  if [ -f "$WRAPFLAG" ]; then
    rm -f "$WRAPFLAG"
    if [ "$STATE" = "live" ] && [ "$LIVE_AT" -gt 0 ] && \
       [ $(( $(date +%s) - LIVE_AT )) -ge "$MIN_RUN" ]; then
      fire_finish guide_operator_wrap_c
    fi
  fi
done
