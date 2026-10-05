# reChhar

```
     🔥🔥🔥   r e C h h a r   🔥🔥🔥
     ─────────────────────────────────────────
     Gaze detection and reaction for Ashita v4
     ─────────────────────────────────────────
     Horizon XI  •  Phoenix XI  •  retail
```

[![License: MIT](https://img.shields.io/badge/License-MIT-cyan.svg?style=for-the-badge)](LICENSE)
[![Framework: Ashita v4](https://img.shields.io/badge/Ashita-v4-ff6b35?style=for-the-badge)]()
[![Status: Live](https://img.shields.io/badge/status-live-00ff00?style=for-the-badge)]()
[![by: Chharizard](https://img.shields.io/badge/by-Chharizard-ff5f87?style=for-the-badge)]()

**When a mob begins a gaze/eye/petrify attack targeting your character, reChhar fires an alarm — and optionally auto-rotates you away.**

Two features, independently toggleable:

- **Alert** (default ON) — big chat warning: `*** GAZE INCOMING: Petrifying Eye from Basilisk - TURN AWAY ***`. Fires on the ability's begin event, 2–3 seconds before it resolves. More than enough time to tap a direction key manually.
- **Autoturn** (default OFF) — sends an outgoing position packet (0x015) to rotate your character away automatically. Experimental; works on some servers, blocked on others.

Era-aware: tracks the right ability sets for base game / ToAU / WoTG / retail. Universal mode: one addon handles every job.

---

## Install

1. Clone this repo (or `git pull` if you already have it)
2. Copy or junction `addons/rechhar/` into `<Ashita>\addons\`
3. In-game: `/addon load rechhar`
4. Configure once; settings persist across sessions

---

## Commands

```
/rechhar on | off               -- master toggle
/rechhar alert on | off         -- chat warning (default ON, always safe)
/rechhar autoturn on | off      -- packet-based auto-rotate (opt-in, experimental)
/rechhar era <base|toau|wotg|retail>
                               -- which gaze set to use
/rechhar list                  -- show tracked gazes for current era
/rechhar test                  -- fire a mock gaze on current target
/rechhar debug                 -- toggle verbose logging
/rechhar faceback              -- restore heading after a manual test
```

---

## Recommended live config

```
/rechhar on
/rechhar alert on         <- always safe, zero risk
/rechhar autoturn off     <- opt-in once you've confirmed it works on your server
```

Alert alone covers the actual gameplay need. Autoturn is a bonus — if the packet injection isn't accepted by your server you can leave it off and still get full value from the alerts.

---

## Era support

| Era | Example gazes tracked |
|---|---|
| base | Stone Gaze, Mortal Ray, Hex Eye, Blaster, Chaotic Eye, Charming Gaze, Petro Eyes |
| toau | +Breath Gaze, Weakening Gaze, Soporific |
| wotg | +Despotic Gaze, Shadow Spread |
| retail | +Daydream, Dreamflower, etc. |

Add server-specific abilities by editing `data/gazes.lua` and committing — pure data, no code changes needed.

---

## Related

- 🔥 [**ChharLAC**](https://github.com/ChharithOeun/ChharLAC) — LuAshitaCast profiles for all 22 jobs
- 🔥 [**ChharClear**](https://github.com/ChharithOeun/ChharClear) — log cleaner + wiki mirrorer
- 🔥 [**Chharizard**](https://github.com/ChharithOeun/Chharizard) — the parent FFXI toolkit

---

## License

MIT. See [LICENSE](LICENSE).
