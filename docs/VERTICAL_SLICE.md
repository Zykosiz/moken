# Moken — Vertical Slice

## Purpose

This is the first playable slice of Moken. Its job is to prove the emotional core of the game — a beautiful, cozy, lived-in island, disrupted by violence, and saved by something stranger and larger than the threat itself — while standing up the baseline RPG systems every later island and Horror will depend on.

The slice does not implement a Horror encounter. It stages the *arrival* of a Horror as a scripted, cinematic event. Building a playable, player-driven Horror sequence is future work (see HORRORS.md); this slice earns the right to build that by proving the world underneath it first.

---

## Emotional Arc

1. **Cozy.** The player experiences the starting island as safe, warm, and alive — village life, dialogue, exploration, no threat.
2. **Threat.** Pirates attack. Islanders are in real danger. The player is not yet equipped to stop it.
3. **Awe/Terror.** The sky blackens. A Horror arrives — not to help the player, but because pirates are prey. It eats the pirate captain.
4. **Gift.** The Horror spits out a pistol. The player character picks it up in an automated, non-interactive sequence.
5. **Departure.** The Horror leaves the island. Light returns — but only to the island. The surrounding sea remains black.

This closing image is the game's real premise made visible: the island is safe again, but the world is still severed. Restoring the sea is the rest of the game.

---

## Scope Boundaries

**In scope for this slice:**
- One fully realized starting island (already substantially built — see ISLAND_LAYOUT.md)
- Baseline RPG systems: dialogue, menus, save/load
- NPC life and village-normalcy content that makes "cozy" land emotionally
- Scripted pirate-attack sequence
- Scripted Horror-arrival cinematic (captain eaten, pistol given, Horror departs)
- Lighting/state change: island relights, sea stays dark
- Player receives the pistol as an item/equip state, ending the slice able to hold it (not necessarily fire it in anger yet)

**Explicitly out of scope for this slice:**
- A fightable/interactive Horror encounter
- Full bullet-type roster or reload-loop balancing (see Combat System below — a prototype is a separate, parallel workstream, not a slice dependency)
- A second island
- Pirate combat as a real system (the attack is staged/scripted, not a fought battle the player resolves)
- Any resolution to "restore the sea" — that stays broken at the end of this slice, on purpose

---

## Core Systems Required

### Dialogue
Standard conversation system: NPC-initiated and player-initiated, branching where needed for village-life flavor, no dependency on combat or inventory state for this slice.

### Menus
Whatever's needed to support save/load, inventory (eventually holding the pistol), and basic settings. Doesn't need to be final art, needs to be functional and consistent.

### Save/Load
Needs to exist before the slice is "done," since it constrains how game state is structured everywhere else. Should be designed early even if implementation lands later — retrofitting save support after systems exist is expensive.

**Confirmed decisions:**
- Manual saving only, triggered at physical save points in the world — no autosave, no save-anywhere.
- Save-point final art is undecided. Current implementation uses a placeholder glowing star/anchor object, to be replaced later once art direction is settled.
- Persisted data: player start position (stored as scene + spawn/marker reference, not raw coordinates, so it survives future layout changes), and a general-purpose quest/event flag system that other systems (dialogue, scripted sequences) read/write against.
- Data structure is designed to extend later for inventory and world-lighting state (e.g. "island relit, sea still dark") without a redesign, though those aren't implemented yet.
- Single vs. multiple save slots: left to implementation recommendation rather than pre-decided.

### Combat System (not part of this slice)
Turn-based RPG combat. The player's core mechanic is the pistol — their equivalent of magic:
- Multiple bullet types, each with a distinct effect
- Reload required after use (a resource/timing constraint, not just flavor)

The pirate attack and pistol handoff in this slice are entirely scripted/cinematic — no player combat input occurs. Combat is confirmed to first become playable on the second island, and is fully decoupled from this slice. This slice only needs the pistol to exist as an item/equip state by its end, not to be fireable.

---

## Scripted Event Sequence (build last, once systems exist)

Pure assembly work once dialogue, menus, save, and the island itself are solid:

1. Trigger: pirate attack begins (staged, not a real fought battle)
2. Escalation: islander lives visibly at stake
3. Transition: sky blackens — needs a clear, readable on-screen distortion beat (per HORRORS.md's principle that transitions must be clearly presented)
4. Horror arrives, kills the captain (or "eats" — implies off-screen/stylized rather than graphic, matching a mature-but-not-gratuitous tone)
5. Horror gives the player the pistol — **fully cinematic, no player input**
6. Horror departs
7. Lighting resolves: island relights, sea remains black
8. Player is left with the pistol in inventory/equip state, slice ends

---

## Build Order (recommended)

Combat is not part of this slice — it's confirmed to debut on the second island and is fully decoupled from everything below.

1. **Save/Load** — in progress. Manual saving via placeholder save-point objects, storing player start position and quest flags, with room to extend for inventory and world-lighting state later. Every other system's state shape (dialogue flags, quest/NPC state, story-sequence progress) depends on this being settled first.
2. **Dialogue and menus** — well-understood systems, build in whatever order is least annoying once save's data shape exists to hook into.
3. **Cozy island content pass** — NPC life, dialogue content, whatever makes the island feel lived-in beyond layout/placement.
4. **Scripted event sequence** — cutscene/timeline tooling, camera lock, lighting-state trigger, assembled last since it depends on everything above existing.

---

## Open Questions

- Exact tone/staging of "eats the captain" — how graphic, how stylized, camera framing during it
- Whether the automated pistol pickup doubles as any kind of tutorial framing (currently: no, purely cinematic)
- What "the sea remains black" actually looks like at the shader/skybox level around the island's coastline
- Whether any of the seven temporary layout-validation NPCs (see ISLAND_LAYOUT.md) survive into the pirate-attack sequence as named, at-risk characters, or whether the attack introduces its own cast