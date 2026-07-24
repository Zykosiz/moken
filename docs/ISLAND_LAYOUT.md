# Island Layout Pass

## Visual Direction

The starting island is being shaped into a bright, warm, peaceful tropical settlement. The layout should read as inhabited and prosperous, with a beach-town harbour, clustered homes, gardens, palms, open scenic green space, and a lighthouse as the dominant high-landmark.

The current pass is spatial blockout and asset-selection work. It is not final decoration, quest staging, combat setup, horror-event setup, or final art polish.

## Asset Inventory And Selection

| Asset path | Type | Intended district | Beach-town fit | Material adjustment | Wrapper |
|---|---|---|---|---|---|
| `res://Assets/Quaternius/Home and Buildings/Ultimate Textured Building Pack - Dec 2019/Models with Materials/FBX/1Story_GableRoof_Mat.fbx` | Building | Beach town, quiet coast, keeper house | Good small pale coastal house | Tinted warmer/paler | `BeachHouseSmall.tscn` |
| `res://Assets/Quaternius/Home and Buildings/Ultimate Textured Building Pack - Dec 2019/Models with Materials/FBX/2Story_Balcony_Mat.fbx` | Building | Beach town, residential slopes | Good balcony house silhouette | Tinted warm plaster | `BeachHouseLarge.tscn` |
| `res://Assets/Quaternius/Home and Buildings/Ultimate Textured Building Pack - Dec 2019/Models with Materials/FBX/3Story_Balcony_Mat.fbx` | Building | Village heart | Good inn/public-building scale | Tinted warm plaster | `VillageInn.tscn` |
| `res://Assets/Kenney/Pirate Kit/structure.glb` | Wooden shed | Harbour | Fits as neutral coastal utility shed | None | `CoastalShed.tscn` |
| `res://Assets/Kenney/Pirate Kit/structure-roof.glb` | Roof/stall piece | Village heart market | Fits if read as simple awning | Warm cloth tint | `MarketStall.tscn` |
| `res://Assets/Kenney/Pirate Kit/structure-platform-dock.glb` | Dock | Main harbour | Good practical dock piece | None | `DockSection.tscn` |
| `res://Assets/Kenney/Pirate Kit/tower-complete-large.glb` | Tower | Lighthouse hill | Usable as blockout lighthouse shell | Pale lighthouse tint | `Lighthouse.tscn` |
| `res://Assets/Kenney/Pirate Kit/platform-planks.glb` | Platform/planks | Stairs/terraces | Usable as broad blockout step piece | Stone tint | `StoneStairSection.tscn` |
| `res://Assets/Kenney/Pirate Kit/structure-fence-sides.glb` | Fence/wall | Terraces, residential slopes | Fits as simple retaining/fence edge | Stone/wood tint | `RetainingWall.tscn` |
| `res://Assets/Kenney/Pirate Kit/palm-detailed-bend.glb` | Palm | All tropical districts | Strong fit | None | `PalmCluster.tscn` |
| `res://Assets/Quaternius/Nature/Nature Crops Pack - Jan 2020/FBX/Flowers_Crop.fbx` | Flowers/garden | Village heart, quiet coast, inland green | Good garden filler | None | `GardenCluster.tscn` |
| `res://Assets/Kenney/Pirate Kit/boat-row-small.glb` | Small boat | Harbour, quiet coast | Good neutral boat | None | Direct layout use |
| `res://Assets/Kenney/Pirate Kit/boat-row-large.glb` | Large rowboat | Harbour | Good neutral transport/fishing boat | None | Direct layout use |
| `res://Assets/Kenney/Pirate Kit/crate.glb` | Prop | Harbour | Good practical harbour prop | None | Direct layout use |
| `res://Assets/Kenney/Pirate Kit/barrel.glb` | Prop | Harbour | Good practical harbour prop | None | Direct layout use |
| `res://Assets/Kenney/Pirate Kit/rocks-sand-b.glb` | Rock | Wild corner, shoreline | Good natural dressing | None | Direct layout use |

## Assets Intentionally Avoided

The pass avoids obvious pirate or hostile staging assets: pirate flags, skull symbols, cannons, cannon balls, mobile cannons, castle gates, castle walls, pirate ships, ghost ships, shipwrecks as decoration, treasure chests, and dark fortification pieces.

Pirate-kit assets are only used where they read as ordinary coastal life: docks, rowboats, barrels, crates, palms, rocks, fences, and shed-like structures.

## District Definitions

- `MainHarbour`: lower coastal shelf with practical docks, boats, crates, barrels, sheds, and preserved future landing space.
- `BeachTown`: densest settlement cluster near the harbour, with small and medium houses placed off-grid around a natural street approach.
- `VillageHeart`: social center with inn, market stalls, plaza, and communal well blockout.
- `ResidentialSlopes`: lower/middle slope houses with retaining wall blockouts and breathing room between clusters.
- `LighthouseHill`: highest suitable sampled hill, sparse and landmark-driven with lighthouse and keeper house.
- `QuietCoast`: relaxed lower-density coastal homes, garden, and small fishing/bathing mood.
- `InlandGreen`: open gardens, palms, and agricultural breathing space.
- `WildCorner`: less-developed vegetation and rock mass with a placeholder future mystery/cove marker.

## Path Hierarchy

The primary path connects:

`MainHarbour -> BeachTown -> VillageHeart -> ResidentialSlopes -> LighthouseHill`

Secondary paths branch to:

- Quiet coast
- Inland green space
- Wild corner
- Harbour service loop

Paths are generated as segmented terrain-sampled strips so they follow the island height at regular intervals rather than using one global Y value.

## Landmark Placement

The lighthouse is placed by sampling the island for the highest suitable hill with enough land mask and acceptable terrain normal. It should dominate the skyline and remain visible from the harbour, village heart, route approaches, and sea-facing viewpoints.

## Harbour Role

The harbour is preserved as the future pirate-attack arrival direction without implementing attack gameplay. It currently reads as a practical settlement harbour with docks, small boats, sheds, and cargo props rather than a pirate fortress.

## Gameplay Anchors

`AuthoredLayout/GameplayAnchors` creates explicit `Marker3D` anchors for:

- Player start layout reference
- Harbour entrance
- Village heart
- Lighthouse entrance
- Future pirate landing
- Future civilian gathering point
- Future horror-event staging
- Future battle transition trigger
- Quiet coast
- Inland green

No events are implemented yet.

## Temporary NPC Placement

The layout pass places seven temporary NPCs for scale:

- two fishers near harbour
- three villagers in village heart
- one slope resident
- one guard near the lighthouse path

They are layout validation NPCs only, not final population.

## Terrain Placement Approach

`AuthoredIslandLayout.gd` uses `WorldTerrainPlacement` for terrain-aware settlement placement. The helper samples `IslandMesh.get_height`, `IslandMesh.get_land_mask`, and `IslandMesh.get_normal`, with center/corner/edge footprint checks for major structures.

Current categories:

- Buildings and large structures: houses, inn, sheds, and lighthouse stay upright, rotate only on Y, sample a footprint, and move to a nearby acceptable position when the original point is too sloped.
- Small props: crates, barrels, market stalls, and pulled-up boats stay upright, use deliberate Y rotation, and sit slightly above the sampled terrain height.
- Vegetation: palms and gardens stay mostly upright with weak terrain-normal alignment.
- Rocks and natural objects: shoreline/wild rocks use stronger terrain-normal alignment and simple blocking collision when large.
- Paths, docks, stairs, and retaining structures: paths sample terrain by segment, docks use a water-relative height, and retaining walls/stairs use simple project-owned collision.

Major buildings receive visible stone terrace/foundation blockouts sized from their approximate footprints. Foundations are local only; the island mesh is not flattened.

Slope thresholds in the current blockout:

- Standard buildings: up to about `1.15m` height difference across the sampled footprint.
- Large buildings: up to about `1.45m`.
- Lighthouse: up to about `1.8m` with a larger foundation.
- Small props: about `0.75m` where footprint checking is needed.

Wrapper scenes expose placement controls (`align_to_surface`, `normal_alignment_strength`, `random_y_rotation`, `random_scale_range`, `surface_offset`) and optional simple player collision. Major structures use collision layer `1` and mask `1`, matching the current default player collision setup.

## Future Staging Notes

- Pirate attack: use the harbour-facing water side and `FuturePirateLanding` anchor.
- Darkness event: use `FutureHorrorEventStaging` near the wild corner, but do not develop it into an arena yet.
- Battle transition: use the harbour/town route marker as a future threshold candidate.

## Unresolved Art Direction Questions

- Whether the lighthouse should become a custom non-pirate model rather than a repurposed tower.
- Whether the Quaternius textured building set should be palette-overridden more selectively instead of broad tinting.
- Whether roads should become actual terrain-decal materials or custom mesh paths in a later pass.
- Whether future stairs should be real walkable ramp/stair geometry or remain broad terrain-following routes.
