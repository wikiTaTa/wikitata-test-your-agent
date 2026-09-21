# Operator Runbook — pilot run `calc-A-basic-1`
**Version 1.6** · revisions increment 1.1, 1.2, 1.3… (never a 2.x without a protocol change)

You are about to operate one instrumented challenge run: tier **A** (bare Claude, no MCP), project **Calculator**, persona **BASIC**. Hands-on setup is a few minutes; then you mostly watch. The run itself ends when the agent finishes or at **45 minutes**, whichever comes first.

This guide assumes nothing. Every step tells you what to do, exactly how to do it, and what you should see before moving on. If what you see doesn't match, stop and check the Troubleshooting section at the bottom — don't improvise.

---

## Words used in this guide

| Word | Means |
|---|---|
| **VM host** | The physical Apple Silicon Mac the run happens on. |
| **VM** | A complete second Mac running *inside a window* on the VM host ("virtual machine"). |
| **Inside the VM** | You clicked into the VM's window, so your keyboard and mouse now control that inner Mac — not the real one. |
| **Terminal** | The app where you type commands. The VM host has one; the VM has its *own separate one*. This guide always says which. |

## What you need before starting

1. **An Apple Silicon Mac as the VM host** (any M-series). The guest VM is macOS; the harness tool ([Tart](https://tart.run)) does not run on Intel Macs, Linux, or Windows — see [README → Platform notes](README.md).
2. **The golden image `tta-base-a` already built on that Mac.** (One-time build; if `tart list` doesn't show it, do the golden-image build first — not this document.)
3. **A way to see the VM host's screen:** sit at it, or connect with macOS Screen Sharing. Either way you are looking at its desktop. *Plain SSH is not enough* — the VM opens as a window on the desktop, and you must see and use that window.

## Your persona: BASIC — the rules while the agent runs

You are playing "a regular user who pasted an instruction and waits." Three rules plus a notebook, no exceptions:

1. If the agent asks a question, answer with the **shortest sensible answer**. Approving permission prompts is fine — that's normal use, not steering.
2. **Never** suggest a feature, tool, design, or approach. Never say "try X". Never point out a problem.
3. Speak unprompted **only** if the agent has sat idle, with no question pending, for about 60 seconds — then type exactly: `continue`
4. Keep a scrap note: anything you type, and roughly when. That note is the operator log and ships with the results.

---

## PART 1 — Start everything (on the VM host)

### Step 1. Open a Terminal on the VM host's desktop

At the VM host (or in your Screen Sharing view of it): click the desktop, press **⌘-space** (hold the command key, tap the space bar), type `Terminal`, press **Return**.

✅ **You should now see:** a window with a text prompt ending in `$` or `%`, waiting for you to type.

### Step 2. Run the launcher

Copy this whole line, paste it at the prompt, press **Return**:

```bash
curl -fsSL https://raw.githubusercontent.com/wikiTaTa/wikitata-test-your-agent/main/scripts/run-pilot.sh | bash
```

The launcher narrates itself: it checks the VM host, stages the export tool, creates a fresh disposable VM, prints the checklist you'll use in Part 2, and then **turns this terminal into the VM** — a new window opens containing an entire second Mac.

✅ **You should now see:** four `OK` lines, a boxed checklist (a filled-in copy of Part 2 below — leave it on screen), and then a **new window** with a macOS desktop booting inside it. Your terminal stops accepting input: it is now attached to the VM for the whole run. That is normal — you never need this terminal again until Part 4, and your prompt comes back when the VM shuts down.

⏳ First boot can take a minute or two. Wait until the inner Mac shows a normal desktop (menu bar, dock, wallpaper).

---

## PART 2 — Prepare the inside of the VM

⚠️ **First: click once inside the VM's window.** From that click on, everything you type goes to the inner Mac. (To get your mouse and keyboard back to the real Mac later, just click outside the window.)

### Step 3. Open the VM's own Terminal

Inside the VM: press **⌘-space**, type `Terminal`, press **Return**.

✅ **You should now see:** a second Terminal — this one belongs to the inner Mac. Everything in Part 2 happens here.

### Step 4. Set up the challenge + start the automatic stills camera

One short line in the VM's Terminal (also printed by the launcher's checklist). It downloads the challenge, starts the 30-second stills camera and the timing log, installs the run tools into `~/tta`, and docks this window to the left:

```bash
curl -fsSL https://raw.githubusercontent.com/wikiTaTa/wikitata-test-your-agent/main/scripts/vm-setup.sh | bash -s calculator calc-A-basic-1
```

✅ **You should now see:** a short narrated list ending in `READY — harness v1.6.12` and `NEXT: ~/tta/begin.sh`.
❌ If you see `command not found` or an error mentioning `curl` or `unzip`: stop, note the exact text, and report it.

### Step 5. Run the guided wizard — from here, you only press Return

One line in the VM's Terminal:

```bash
~/tta/begin.sh
```

The wizard **pages like an installer**: each screen shows the step tracker and exactly ONE **pulsing** `PRESS RETURN` action — do whatever pulses. In order, it: confirms the stills camera is rolling → starts the **screen recording** (a clock window docks bottom-right; ticking clock = recording) → opens the **run guide** (top-right) and loads the startup instruction onto the clipboard → launches the agent (Claude Code) right in the wizard's window.

- If macOS asks for the **Screen Recording permission**, the wizard shows a retry page: click **Allow** (System Settings opens: switch **Terminal** on, password `admin`, let Terminal quit & reopen), run `~/tta/begin.sh` again if needed — re-running is always safe. The wizard will not move past that page until the recording is verified live. *(The recording is a mandatory evidence witness for instrumented runs; see CAPTURE.md for casual runs.)*
- The three windows tile themselves without overlap: wizard/MAIN left, guide top-right, recording clock bottom-right. *(First time, macOS may ask to let Terminal control Finder — that's only for window positioning; Allow or Deny, everything works either way.)*
- 📺 Re-check the recording any time: `pgrep -x screencapture >/dev/null && echo YES || echo NO`

---

## PART 3 — The run itself

### Step 6. Follow the guide window — it advances by itself

The guide (top-right) is live: it always shows your **one next move** in a pulsing `DO THIS NOW` box, and moves to the next panel on its own as it detects the run's real signals (agent launched → instruction pasted → run live → recording stopped). You never type in the guide window.

At the wizard's last `PRESS RETURN`, Claude Code opens in the MAIN window — no login. Then, per the guide: click into Claude Code, press **⌘V** (or Edit → Paste), press **Return**.

The pasted text is exactly this — shown here for reference only; you never need to hand-copy it:

> You are starting a new project. The complete specification is in PROJECT-BRIEF.md in this repository.
>
> Build the **Pocket Scientific Calculator** exactly as specified, as 4 parallel work streams (lanes A–D in the brief).
>
> Before any code: design the implementation of the entire project — including how you will execute and coordinate the 4 work streams — **optimized for the coordination capabilities available to you.** Then execute that design.
>
> Requirements:
> 1. All 4 lanes' scope must ship. All modules must integrate cleanly — no merge conflicts, no duplicate or competing components, no broken imports.
> 2. Design the app's visual appearance **from scratch**. No reference designs exist; visual quality will be judged.
> 3. Target: under 15 minutes total wall-clock. Speed matters, but a broken build scores zero.
> 4. Keep a step-by-step record of everything you do: decisions, agent dispatches, file writes, integration steps.
> 5. Done = the build succeeds and the app runs with every specified feature working.

⏱ **The moment you press Return, the run has started.** Persona rules (top of this page) govern everything you do from now on. Note the time.

### Step 7. Watch. The run ends two ways

- The agent declares it is **done** → open a **new** Terminal window (**⌘N**) and run `~/tta/finish.sh` — it starts the dev server, puts the finished app on camera in Safari, then stops the recording and wraps up by itself.
- **45 minutes** pass since the paste → the recording window (bottom-right) starts **pulsing CLICK HERE**: click it and press **Ctrl-C**, then follow the guide's wrap-up panel.

---

## PART 4 — Stop, save, export

### Step 8. Stamp the end + finalize the recording (inside the VM)

1. As the guide's wrap-up panel says: open a **new** Terminal window inside the VM (**⌘N**) and run — it stamps the end time, stops + finalizes the recording, and prints the export command:
   ```bash
   ~/tta/end-run.sh
   ```
✅ **You should now see:** `recording.mov` listed with a large file size, and `>>> RECORDING STOPPED AND SAVED <<<`. The recording window drops back to a prompt — its banner gone is your visual confirmation.

### Step 9. Export the results bundle (on the VM host)

Click **outside** the VM window (you're back on the real Mac). Open a **new** Terminal (⌘-space → `Terminal` — the old one is still attached to the VM; leave it). Paste:

```bash
cd ~/tta-runs/staging && ./export-run.sh run-calc-A-basic-1 calc-A-basic-1
open ~/tta-runs/calc-A-basic-1/index.html
```

✅ **You should now see:** a list of what was pulled out of the VM (repo, transcripts, stills, recording…), then the **Run Viewer** page opening — a flip-book of the stills with the video below it.

### Step 10. Hand off

Report where the bundle is (`~/tta-runs/calc-A-basic-1` on the VM host). Analysis, token accounting, the time tally, and the run-report card are generated from it (`node scripts/analyze-run.mjs <bundle-dir>`). **Do not delete the VM** — leave it stopped for inspection.

---

## Troubleshooting

| What you see | What it means / what to do |
|---|---|
| Launcher ends with "plain SSH session" text instead of a VM window | You ran it over SSH. Do Step 1 at the VM host's desktop (or via Screen Sharing) and run the printed `tart run` command there. |
| No VM window after Step 2 | In a new VM-host Terminal: `tart list` — if the VM says `running` but there's no window, report it; if `stopped`, run `tart run run-calc-A-basic-1` from a desktop Terminal. |
| Typing goes to the wrong Mac | Click once inside the VM window to type into the VM; click outside it to type on the real Mac. |
| `golden image not found` | The one-time golden-image build hasn't been done on this VM host. |
| Agent sits idle >60s with no question | Persona rule 3: type exactly `continue`. |
| **Anything else** | Stop. Note the exact text and the step number. Leave everything as-is and report. A stopped run that teaches us something is the pilot doing its job. |

---
*Revisions: 1.0 initial · 1.1 tart-run-holds-terminal fix · 1.2 state-based expectations + health checks · 1.3 display-path split · 1.4 generic operator rewrite (platform section, no host specifics) · 1.5 novice-fidelity rewrite: defined terms, per-step ✅ verification, manual-recording warning, zero-tab launcher flow, troubleshooting table · 1.6 wizard-paged flow: begin.sh drives recording/guide/launch, self-advancing pulsing run guide, non-overlapping window tiling.*
