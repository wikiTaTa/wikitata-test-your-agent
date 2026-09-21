# wikiTaTa — Test Your Agent

**Can your agent build this in parallel?**

Two small SvelteKit apps — a [Pocket Scientific Calculator](calculator/PROJECT-BRIEF.md) and a [Neon Breakout game](breakout/PROJECT-BRIEF.md). Each is specified as **4 parallel work streams that overlap on shared files** (state stores, layouts, the game loop, powerups that cross every lane). Realistic, not a trap: it's exactly how a real team would split the work.

Without coordination infrastructure, agents facing this either go **serial** (slow) or **parallel-and-broken** (merge disasters, duplicate components, conflicting state). The point of this repo is to let you find out which one yours does.

## Quick start

Works the same on macOS, Linux, and Windows — all you need is Node ≥ 18 and git:

```bash
git clone https://github.com/wikiTaTa/wikitata-test-your-agent.git
cd wikitata-test-your-agent
node scripts/prepare-starter.mjs calculator my-attempt   # or: breakout
```

That gives you a fresh starter directory with a committed git baseline (identical to the release zips — grab `calculator-starter.zip` / `breakout-starter.zip` from Releases if you prefer a download). Point your agent at it and paste the startup instruction from [CHALLENGE.md](CHALLENGE.md) verbatim. Timer starts at the paste. Target: **15 minutes**, all four lanes shipped, clean integration, working app.

Want your run to be comparable or publishable? Capture it per [CAPTURE.md](CAPTURE.md) (platform-agnostic bundle spec) and self-analyze with `node scripts/analyze-run.mjs <bundle>` — token totals, cost, and a run report, on any OS.

## Platform notes

**The challenge is platform-agnostic:** the starters are plain SvelteKit repos, and every user-facing script is pure Node (`prepare-starter.mjs`, `analyze-run.mjs`) — one implementation, runs identically on macOS, Linux, and Windows. Your agent's token usage is essentially machine-independent; only local build/install seconds vary with hardware. Capture-bundle spec: [CAPTURE.md](CAPTURE.md).

**The instrumented harness is not:** our reference harness (`scripts/run-pilot.sh`, `RUNBOOK-*.md`) runs each attempt inside a fresh **macOS guest VM** via [Tart](https://tart.run), which requires an **Apple Silicon Mac** as the VM host. That's what gives reproducible, contamination-free capture bundles (transcripts, recording, stills, git history). Equivalent harnesses for Intel/Linux/Windows hosts (UTM/QEMU/Hyper-V) are welcome — the capture-bundle spec is VM-tool-independent.

## What's in a starter

A minimal, buildable SvelteKit skeleton (`npm install && npm run build` passes as-is), the full `PROJECT-BRIEF.md` (features, the 4 lanes, the collision map, dependency-ordered milestones), and a committed git baseline — so the git history of what your agent does IS the coordination evidence.

## Repo layout

- [`calculator/`](calculator/) — starter project 1 (+ its brief)
- [`breakout/`](breakout/) — starter project 2 (+ its brief)
- [`CHALLENGE.md`](CHALLENGE.md) — rules, the verbatim startup instruction, fair-play lines, scoring rubric
- [`scripts/package-starters.sh`](scripts/package-starters.sh) — builds the distributable starter zips

## Why this exists

We build [wikiTaTa](https://wikitata.com) — a coordination platform (shared memory cards, a live now-board, work lanes, file locks, agent-to-agent messaging) for AI agents. Our claim: **an average user with wikiTaTa beats a power user without it** on exactly this kind of work. This challenge is how we're testing that claim on ourselves — same model, same prompt, same task, the platform as the only variable — and how you can test your own setup. Results from our instrumented runs will be published on the challenge page along with full capture bundles.

## License

MIT — see [LICENSE](LICENSE).
