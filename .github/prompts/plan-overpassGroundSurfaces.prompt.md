## Plan: Overpass-Driven Ground Surfaces

Replace the single green chunk plane with data-driven surface polygons from Overpass while keeping a chunk-wide fallback collision base. Reuse the existing chunk queue, cache, and spawner architecture, then extend parsing to landuse/natural/surface with relation multipolygon support and a polygon-only street pipeline (prefer explicit road areas; otherwise buffer centerlines using tag-derived widths).

**Steps**
1. Phase 1: Extend Overpass fetch scope and cache versioning in [SpawnManager.gd](SpawnManager.gd).
2. Add Overpass query terms for surface-relevant ways/relations (landuse, natural, surface) plus detailed road sources (highway ways and road-area relations/ways) for polygon-based street generation.
3. Introduce a query/schema version constant and include it in cache keys to invalidate old cached payloads safely when the query changes. Depends on step 1.
4. Build parsed buckets for surface candidates during JSON processing, keeping existing object buckets unchanged to avoid regressions. Depends on step 1.
5. Phase 2: Build geometry extraction and classification pipeline in [SpawnManager.gd](SpawnManager.gd), reusing coordinate conversion patterns from [objects/house/house_spawner.gd](objects/house/house_spawner.gd) and [objects/street/street_spawner.gd](objects/street/street_spawner.gd).
6. Convert way/relation geometries into chunk-local 2D polygons, including outer/inner rings for multipolygon relations. Depends on step 4.
7. Classify each polygon into normalized surface types (for example: water, grass, forest, residential, industrial, farmland, asphalt, concrete, gravel, dirt) with explicit precedence when multiple tags exist. Depends on step 6.
8. Apply unknown-tag fallback to default grass classification and keep robust guards for malformed geometry. Depends on step 7.
9. Route highway features away from general ground-surface output into a dedicated street-polygon pipeline: use explicit road polygons when present, otherwise derive buffered polygons from centerlines using width, then lanes, then highway-type defaults. Depends on step 6.
10. Phase 3: Refactor [objects/ground/ground_spawner.gd](objects/ground/ground_spawner.gd) into async data-driven spawning.
11. Replace spawnGround with handleData-style input (surface polygon payload + tile center) and batched frame yielding aligned with other spawners. Depends on step 7.
12. Keep one chunk-wide fallback base layer (with collision) for hole protection; create individual surface polygons without collision as requested. Depends on step 11.
13. Implement hybrid rendering: strong color palette per surface type plus optional texture hooks per material for later upgrades. Depends on step 11.
14. Introduce draw-priority/y-offset rules to avoid z-fighting between base layer, surface polygons, and street polygons. Depends on steps 9 and 12.
15. Phase 4: Integrate and preserve behavior in [SpawnManager.gd](SpawnManager.gd) and [spawner.tscn](spawner.tscn).
16. Feed parsed surface payload to GroundSpawner before other object spawners; keep existing call order otherwise stable. Depends on steps 4 and 11.
17. Preserve chunk lifecycle safety checks (is_instance_valid guards, unload handling) and ensure partial-load cancellation does not leak surface nodes. Depends on step 16.
18. Refactor [objects/street/street_spawner.gd](objects/street/street_spawner.gd) into the sole road renderer using polygons only (no Path3D street shape), and ensure highway features are emitted exactly once. Depends on step 14.
19. Remove StreetSpawner dependency on [objects/street/street_shape.tscn](objects/street/street_shape.tscn) and delete or deprecate the scene to prevent accidental reintroduction of line-based roads. Depends on step 18.
20. Phase 5: Performance, seam quality, and resiliency hardening.
21. Add polygon count and batching thresholds to prevent frame spikes in dense tiles; degrade gracefully by skipping lowest-priority decorative surfaces first if needed. Depends on step 11.
22. Handle cross-chunk geometry consistently to avoid visible seams (shared classification rules and stable clipping behavior at chunk bounds). Depends on step 6.
23. Keep fallback behavior when Overpass returns sparse/invalid surface data so chunks remain traversable and visually coherent. Depends on steps 8 and 12.

**Relevant files**
- [SpawnManager.gd](SpawnManager.gd) — Extend query, parse additional Overpass elements, classify surfaces, split highway features into street-polygon input (not ground), version cache keys, pass payloads to GroundSpawner and StreetSpawner.
- [objects/ground/ground_spawner.gd](objects/ground/ground_spawner.gd) — Convert to async surface-polygon spawner with base collision layer and per-surface visual layers.
- [objects/ground/ground.tscn](objects/ground/ground.tscn) — Rework from fixed giant plane into fallback base-ground resource/preset used by GroundSpawner.
- [spawner.tscn](spawner.tscn) — Keep node wiring valid for refactored GroundSpawner and optional exposed tuning parameters.
- [objects/street/street_spawner.gd](objects/street/street_spawner.gd) — Replace Path3D road rendering with polygon generation (explicit areas first, buffered centerlines second) and align elevation/render order with nearby surface layers.
- [objects/street/street_shape.tscn](objects/street/street_shape.tscn) — Remove or deprecate this line-based street shape scene once polygon street rendering is in place.
- [calculator.gd](calculator.gd) — Reuse existing meter conversion logic; no functional changes expected unless helper extraction is needed.

**Verification**
1. Chunk loading sanity: run game, move across multiple tiles, confirm no load deadlocks and chunk visibility toggles still behave correctly.
2. Surface diversity check: validate distinct rendering appears for mixed OSM areas (for example water, landuse zones, natural areas, paved zones).
3. Relation coverage: test in an area known for multipolygon relations and verify holes/inner rings are respected.
4. Road polygon behavior: verify highways render only as polygons (no path/line mesh fallback), using explicit area geometry when available and width-derived centerline buffering otherwise.
5. Collision contract: confirm only the chunk fallback layer has collision and individual surface polygons do not affect physics.
6. Seam and z-fighting pass: cross chunk borders at speed and inspect for cracks, overlaps, or flicker between base/surface/street-polygon layers (with roads rendered only once).
7. Cache migration: confirm old cache entries are not reused after query expansion (new key/version path used) and subsequent loads hit cache as expected.
8. Performance pass: stress a dense urban tile and confirm frame pacing remains acceptable with batching.

**Decisions**
- Include landuse + natural + surface sources in v1.
- Use hybrid rendering (clear per-type colors now, texture-ready material hooks).
- Unknown/missing tags fall back to grass/default ground.
- Roads are rendered only as polygons by StreetSpawner; ground surfaces explicitly exclude highway polygons.
- Support ways plus relation multipolygons in v1.
- Width fallback profile uses realistic urban defaults when width/lanes tags are missing.
- When both explicit road-area polygons and centerlines exist, explicit road-area polygons take priority.
- Keep a chunk-wide fallback base layer with collision; individual surface shapes have no collision.

**Further Considerations**
1. Keep a strict road-ownership rule in parsing (highway tags never emitted into ground polygons) and enforce deterministic street polygon derivation order: explicit area polygon -> width tag -> lanes tag -> realistic highway-class default.
2. Surface precedence should be deterministic (for example natural=water overriding generic landuse) and documented once to prevent future drift.
3. If relation-heavy tiles cause spikes, stage simplification/clipping as a controlled fallback rather than silently dropping all relation surfaces.
