# reChhar

```
     🔥🔥🔥   r e C h h a r   🔥🔥🔥
     ─────────────────────────────────────────
     Ashita port of React: auto-face-away during
     gaze attacks, auto-face-back when resolved.
     ─────────────────────────────────────────
     Era-cap aware  •  Horizon  •  Phoenix  •  retail
```

[![License: MIT](https://img.shields.io/badge/License-MIT-cyan.svg?style=for-the-badge)](LICENSE)
[![Framework: Ashita v4](https://img.shields.io/badge/Ashita-v4-ff6b35?style=for-the-badge)]()
[![Status: Scaffold](https://img.shields.io/badge/status-scaffold-ffd700?style=for-the-badge)]()
[![Based on: React](https://img.shields.io/badge/based%20on-React%20by%20Byrth-00ffff?style=for-the-badge)]()

**Ashita port of the Windower [React](https://github.com/Windower/Lua) addon by Byrth. Automatically faces your character away when a mob begins a gaze attack, then faces back when the action resolves.**

Protects against:
- Petrification gazes (Medusa, catoblepas, basilisks)
- Death gazes (chimeras, taurus, ahriman eyes)
- Charm gazes (succubus, bombs)
- Hundred Fists / Mijin Gakure prep windows (configurable)
- Any ability you add to the database

Era-aware: ships with ToAU-cap ability sets by default; retail players can enable later-expansion gaze abilities via `/rechhar era retail`.

---

## Status

**🚧 Scaffold — core logic porting in progress 🚧**

What's here now:
- Addon skeleton (`rechhar.lua`, `manifest.xml`)
- Ability database stub (`data/gazes.lua`)
- Config loader (`data/settings.lua`)
- Commands wired (`/rechhar on|off|era|debug`)
- Chat-event hook stubs

What's not here yet (coming when the base React source is linked):
- The actual "turn away" mechanic (hooking the facing packet)
- Per-ability face-away timing (some abilities telegraph for 2s, others for 5s)
- Range check (only react when within the mob's gaze range)
- Face-back-after-resolve logic

The gaze database is already structured for all jobs since any job can be a gaze target — reChhar doesn't need per-job profiles like ChharLAC does.

---

## Install (when ready)

1. Clone this repo
2. Copy `addons/rechhar/` into `<Ashita>\addons\`
3. In-game: `/addon load rechhar`
4. `/rechhar on` to enable auto-reaction

---

## Commands (planned)

```
/rechhar on | off           -- master toggle
/rechhar era <toau|wotg|retail>
                           -- which gaze set to use
/rechhar add "<ability>"    -- add a custom ability to the react list
/rechhar remove "<ability>"
/rechhar list               -- show currently tracked abilities
/rechhar debug              -- print state + last incoming action
```

---

## Credits

- Base concept: [React](https://github.com/Windower/Lua) by **Byrth** (Windower addon)
- Ashita port: ChharithOeun
- Framework: Ashita v4 (ThornyFFXI)

---

## Related

- 🔥 [**ChharLAC**](https://github.com/ChharithOeun/ChharLAC) — LuAshitaCast profiles for all 22 jobs
- 🔥 [**ChharClear**](https://github.com/ChharithOeun/ChharClear) — log cleaner + wiki mirrorer
- 🔥 [**Chharizard**](https://github.com/ChharithOeun/Chharizard) — the parent FFXI toolkit

---

## License

MIT, matching the base React addon's spirit. See [LICENSE](LICENSE).
