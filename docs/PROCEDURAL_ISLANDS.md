# Moken — Procedural Small Islands (Future Scoping Note)

Status: **not started, not needed yet.** This is a scoping note written during early vertical-slice development, to be revisited later if/when the game's core loop is validated and worth scaling up. Do not build this now.

---

## Context

Moken has three island categories:

- **Small islands** — secrets, side content, may contain a Horror dungeon entrance. Good candidates for procedural generation.
- **Medium islands** — the main Horror islands. Hand-built, or hand-built with AI assistance. Not procedural.
- **Large islands** — a handful of bigger islands for cities and major settlements. Not procedural.

This note only concerns **small islands.**

---

## Intended Use: Authoring Aid, Not Runtime System

Small islands should be generated **once, by a tool, during development** — not regenerated live in the shipped game. The workflow is: generate a shape → review/adjust it → lock it in as real, hand-editable content, the same way the main island's layout now works (owned nodes, not silently-regenerated-on-load).

This matters because these islands are meant to hold specific, intentional content (a dungeon entrance, a secret), not be different every playthrough.

---

## What Already Exists and Would Be Reused

Built for the main island, and directly reusable for small islands without new work:

- Terrain height/normal sampling
- Prop-to-slope alignment (rocks, foliage placement logic)
- Scatter density and rotation/scale variance (the "doesn't look robotic" logic)
- Node ownership pattern, so generated results are inspectable and hand-editable afterward, not wiped on reload

This is most of the hard-won infrastructure from the first island's build — the procedural work only needs to plug into it, not reinvent it.

---

## What Would Actually Be New

Roughly in order of difficulty:

1. **Island shape/heightmap generation** — the one genuinely new problem. Likely approach: noise-based generation (Perlin/simplex, or a radial falloff combined with noise) thresholded into a landmass, then fed into the existing terrain systems. Well-trodden territory in general game dev; not a research problem, just implementation work.
2. **Size/complexity variance** — small islands are meant to be simple (one landmass, sparse scatter, one or two points of interest) — no need for the district/multi-biome complexity the main island has. This keeps the generator's scope smaller than it might first sound.
3. **Point-of-interest placement** — deciding where a secret or dungeon entrance goes on a given generated shape. Can start simple (highest point, furthest-from-coast point, or constrained random) and improve later if needed.
4. **Variety/seeding** — avoiding sameyness across many generated islands. Solvable with the same jitter/variance instincts already used for scatter props.

---

## Honest Difficulty Assessment

Comparable in complexity to the AuthoredIslandLayout split-refactor already completed — a reasonable, well-scoped build, not a major unknown. Meaningfully smaller in risk/uncertainty than, for example, the Horror encounter system or the cutscene/timeline tooling, both of which involve more undecided design surface.

---

## Revisit Criteria

Come back to this once:
- The vertical slice is done and the core loop feels good
- There's real conviction the game is worth scaling to many islands
- The main island and medium Horror-island content pipeline are stable enough that a second, procedural pipeline won't be built against a moving target
