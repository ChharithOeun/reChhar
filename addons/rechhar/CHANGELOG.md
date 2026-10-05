# reChhar Changelog

## v0.2.0 — 2026-10-04
First functional release. Ported the main logic from Sammeh/Byrth's React.

### Added
- Packet 0x028 parser identifies incoming abilities and spells targeting the player
- `faceAway(mobIdx)` / `faceBack()` using Byrth/Langly's atan2 heading math
- Gaze detection via `gazes.lookup(name, era)` — fires turn-away on ability begin, turn-back on resolve
- `/rechhar test` — try face-away on current target to verify heading math works on your Ashita build
- `/rechhar debug` — verbose packet + reaction logging
- Settings persist across sessions (`enabled` + `era` saved)

### Design
- **Universal mode only** (no per-job files). Original React had 22 per-job files to let you define different reactions per job; reChhar's design is simpler: just face away on gaze, face back when it resolves. If per-job behavior is needed later we can bolt it on.
- **No movement injection.** Original React had `runaway`/`runto`; omitted here because character movement from an addon is riskier on era servers for TOS reasons, and turning away covers 90% of gaze defense.

### Credits
- Sammeh — original React (2016)
- Byrth — maintenance
- Langly — the vector-based turnaround math
- ChharithOeun — Ashita port

### Notes for self
- `setHeading` uses `SetLocalHeading` with a `SetHeading` fallback. If your Ashita build names it differently, override just that function.
- `rechhar.lua` is ~230 lines — intentionally small. If a feature needs more, it probably belongs in a sibling file.

---

## v0.1.0 — 2026-10-04
Initial scaffold:
- Addon skeleton, manifest, command handler stubs
- `data/gazes.lua` with base/ToAU/WoTG/retail ability tiers
- `data/settings.lua` with persistent config loader
- TODO stubs for packet parse + facing control
