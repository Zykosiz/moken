# Moken — Vertical Slice

## Purpose

This is the first playable slice of Moken. Its job is to prove the emotional core of the game — a beautiful, cozy, lived-in island, disrupted by violence, and saved by something stranger and larger than the threat itself — while standing up the baseline RPG systems every later island and Horror will depend on.

The slice does not implement a Horror encounter. It stages the *arrival* of a Horror as a scripted, cinematic event. Building a playable, player-driven Horror sequence is future work (see HORRORS.md); this slice earns the right to build that by proving the world underneath it first.

---

## Opening Premise

The player character arrives on the starting island to take over as its new lighthouse keeper.

The old keeper is preparing to leave or retire, and the opening gives the player time to learn the island, meet its people, and understand the responsibility they are inheriting. The villagers should treat the player's arrival as a small but meaningful event: the lighthouse is part of the island's safety, identity, and connection to the wider sea.

The player is meant to begin the game believing they are settling into a quiet, useful life.

Before they can complete their first real night as lighthouse keeper, the pirates attack and the Horror arrives.

This creates an intentional piece of unfinished business. The player inherits the duty of guiding ships and protecting travelers, but the world changes before they can truly perform it. That local responsibility becomes a thematic preview of the larger journey: bringing light, safety, and connection back to a severed world.

---

## Emotional Arc

1. **Arrival.** The player comes to the island to become its new lighthouse keeper and is welcomed into a new role and community.
2. **Cozy.** The player experiences the starting island as safe, warm, and alive — village life, dialogue, exploration, and the lighthouse handover, with no immediate threat.
3. **Threat.** Pirates attack. Islanders are in real danger. The player is not yet equipped to stop it.
4. **Awe/Terror.** The sky blackens. A Horror arrives — not to help the player, but because pirates are prey. It eats the pirate captain.
5. **Gift.** The Horror spits out a pistol. The player character picks it up in an automated, non-interactive sequence.
6. **Departure.** The Horror leaves the island. Light returns — but only to the island. The surrounding sea remains black.

This closing image is the game's real premise made visible: the island is safe again, but the world is still severed. Restoring the sea is the rest of the game.

---

## Scope Boundaries

**In scope for this slice:**
- One fully realized starting island (already substantially built — see ISLAND_LAYOUT.md)
- The player's arrival as the island's new lighthouse keeper
- The old keeper's handover and introduction to the lighthouse responsibility
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
- The player successfully completing a normal first night as lighthouse keeper before the attack

---

## Core Systems Required

### Dialogue
Standard conversation system: NPC-initiated and player-initiated, branching where needed for village-life flavor, no dependency on combat or inventory state for this slice.

The opening dialogue should establish the lighthouse handover, introduce the old keeper, and let the villagers react to the player's arrival naturally rather than through a single exposition scene.

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

## Opening Sequence

1. The player arrives on the island to replace the current lighthouse keeper.
2. The old keeper welcomes them and begins the handover.
3. The player is introduced to the lighthouse, its purpose, and the island community it protects.
4. The player explores the island and meets villagers who react to the arrival of their new keeper.
5. The day builds toward the player's first night of responsibility.
6. Before that first normal night can happen, the pirate attack begins.

The lighthouse handover should feel hopeful and ordinary. Its purpose is to give the player a future on the island before that future is interrupted.

---

## Scripted Event Sequence (build last, once systems exist)

Pure assembly work once dialogue, menus, save, and the island itself are solid:

1. Trigger: pirate attack begins before the player completes their first night as lighthouse keeper
2. Escalation: islander lives visibly at stake, and the place the player has just accepted responsibility for is threatened
3. Transition: sky blackens — needs a clear, readable on-screen distortion beat (per HORRORS.md's principle that transitions must be clearly presented)
4. Horror arrives, kills the captain (or "eats" — implies off-screen/stylized rather than graphic, matching a mature-but-not-gratuitous tone)
5. Horror gives the player the pistol — **fully cinematic, no player input**
6. Horror departs
7. Lighting resolves: island relights, sea remains black
8. Player is left with the pistol in inventory/equip state and an interrupted duty that now points toward the wider world; slice ends

---

## Build Order (recommended)

Combat is not part of this slice — it's confirmed to debut on the second island and is fully decoupled from everything below.

1. **Save/Load** — in progress. Manual saving via placeholder save-point objects, storing player start position and quest flags, with room to extend for inventory and world-lighting state later. Every other system's state shape (dialogue flags, quest/NPC state, story-sequence progress) depends on this being settled first.
2. **Dialogue and menus** — well-understood systems, build in whatever order is least annoying once save's data shape exists to hook into.
3. **Lighthouse handover and cozy island content pass** — old keeper, lighthouse introduction, NPC life, village dialogue, and whatever makes the island feel lived-in beyond layout/placement.
4. **Scripted event sequence** — cutscene/timeline tooling, camera lock, lighting-state trigger, assembled last since it depends on everything above existing.

---

## Open Questions

- Who the old lighthouse keeper is, why they are leaving, and whether they remain on the island during the attack
- How much of the lighthouse handover is playable versus presented through dialogue and staging
- Whether the player reaches the point of preparing or attempting to light the beacon before the pirate attack interrupts them
- Exact tone/staging of "eats the captain" — how graphic, how stylized, camera framing during it
- Whether the automated pistol pickup doubles as any kind of tutorial framing (currently: no, purely cinematic)
- What "the sea remains black" actually looks like at the shader/skybox level around the island's coastline
- Whether any of the seven temporary layout-validation NPCs (see ISLAND_LAYOUT.md) survive into the pirate-attack sequence as named, at-risk characters, or whether the attack introduces its own cast