# reChhar Changelog

## v0.3.2 — 2026-10-04
- Fix autoturn packet: Ashita v4 `AddOutgoingPacket` wants a byte-table, not a string
- Still experimental: packet goes out but visible rotation depends on server-side acceptance

## v0.3.1 — 2026-10-04
- Surface `AddOutgoingPacket` errors to debug output
- Try both 2-arg and 3-arg API signatures

## v0.3.0 — 2026-10-04
- Split reaction into two independent features
  - **Alert** — big chat warning (default ON, zero risk)
  - **Autoturn** — packet 0x015 injection to auto-rotate (default OFF, opt-in)
- New commands: `/rechhar alert on|off`, `/rechhar autoturn on|off`
- Settings persist across sessions

## v0.2.6 — 2026-10-04
- Fix nil `entity` in `selfIndexByScan` (forward-declaration ordering)
- Rebranded as Chharizard build (dropped external attribution)

## v0.2.5 — 2026-10-04
- Confirmed `GetMemberTargetIndex(0)` returns correct self-index via dual-method cross-check
- Diagnostic: memory writes succeed but engine ignores Entity::SetHeading for player rendering → packet approach needed

## v0.2.0–0.2.4 — 2026-10-04
- Initial addon skeleton with packet 0x028 action parser
- Universal gaze database (base / ToAU / WoTG / retail)
- Debug diagnostics for self-index resolution and heading math

## v0.1.0 — 2026-10-04
Scaffold: manifest, command handler, settings loader.
