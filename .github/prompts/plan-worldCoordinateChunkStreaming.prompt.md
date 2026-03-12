# Plan: World-coordinate chunk system with streaming load/unload

## TL;DR
Replace the center-relative chunk coordinate system with absolute Web Mercator tile coordinates. Chunks are keyed by their real-world tile index (independent of lat_center), so cache files survive teleports. The game world origin floats (recentered when player drifts far from it), and chunk geometry is repositioned rather than respawned when the origin shifts. Chunks outside render distance are unloaded automatically. Render distance is configurable from the pause menu.

---

## Coordinate design

Web Mercator tile: `tile = Vector2i(floor(mx / CHUNK_M), floor(my / CHUNK_M))`  
where `mx = EARTH_RADIUS * lon_rad`, `my = EARTH_RADIUS * ln(tan(...))`, `CHUNK_M = ~1000 m (choose a round meter value)`.

Each chunk root's 3D world position = `(tile * CHUNK_M - origin).xz` where `origin` is the current floating origin in meters.

---

## Phases

### Phase 1 — Absolute tile key everywhere

**1a. calculator.gd**
- Drop the unused `_lat` param from `lonToMeter(_lat, lon)` → `lonToMeter(lon)` (it was never used); update the one internal caller in `latLonToCoordsInMeters`
- Add `const CHUNK_M = 1000.0` (exact meter size)
- Add `latLonToTile(lat, lon) -> Vector2i`: `Vector2i(int(floor(latToMeter(lat)/CHUNK_M)), int(floor(lonToMeter(lon)/CHUNK_M)))` — x = northing tile index, y = easting tile index, matching the existing `center_x = latToMeter` / `center_y = lonToMeter` axis convention throughout the codebase
- Add `metersToLatLon(mx: float, my: float) -> Vector2`: inverse Web Mercator projection, used to convert tile corner meter coords back to lat/lon for Overpass bbox queries:
  - `lat = (2.0 * atan(exp(mx / EARTH_RADIUS)) - PI / 2.0) * 180.0 / PI`
  - `lon = (my / EARTH_RADIUS) * 180.0 / PI`
  - returns `Vector2(lat, lon)`

**1b. SpawnManager.gd — cache key**
- Change `_cache_path(chunk)` to take `Vector2i tile` as its argument, use `tile.x`/`tile.y`
- Old cache files (with relative coords) won't match → will just miss and re-fetch, then save correctly

**1c. SpawnManager.gd — _fetchAllCoordinates**  
- Compute tile bbox corners using `calculator.metersToLatLon` on the tile's meter bounds — no more `lat_center`/`lat_span`/`lon_span`:
  ```gdscript
  var min_corner = calculator.metersToLatLon(tile.x * CHUNK_M, tile.y * CHUNK_M)
  var max_corner = calculator.metersToLatLon((tile.x + 1) * CHUNK_M, (tile.y + 1) * CHUNK_M)
  # lat1=min_corner.x, lon1=min_corner.y, lat2=max_corner.x, lon2=max_corner.y
  ```

---

### Phase 2 — Floating origin

**2a. main.gd**
- Replace `center_x`/`center_y`, `lat_center`/`lon_center`, `lat_span`/`lon_span`, `chunk_size` with:
  - `origin_mx: float`, `origin_my: float` — floating origin in absolute Web Mercator meters (64-bit); axis convention preserved: `origin_mx = latToMeter(lat)` (northing), `origin_my = lonToMeter(lon)` (easting)
- Fix `latLonToCoordsInMeters(lat, lon)` to use new fields with axes unchanged from current code:
  `return Vector2(calculator.latToMeter(lat) - origin_mx, calculator.lonToMeter(lon) - origin_my)`
- Remove `getChunkWidth()` and `getChunkHeight()` — superseded by the fixed `CHUNK_M` constant
- Replace `getCurrentChunk() -> Vector2` with a pure meter-based tile version:
  ```gdscript
  func getCurrentTile() -> Vector2i:
      var pos = playerManager.getPlayerPosition()
      return Vector2i(int(floor((origin_mx + pos.x) / CHUNK_M)), int(floor((origin_my + pos.z) / CHUNK_M)))
  ```
  (pos.x maps to the northing axis = origin_mx axis; pos.z maps to the easting axis = origin_my axis)
- Add `const CENTER_SHIFT_THRESHOLD = 5000.0`; in `_process` trigger `_recenter` when `abs(pos.x) > CENTER_SHIFT_THRESHOLD or abs(pos.z) > CENTER_SHIFT_THRESHOLD`
- Add `_recenter(new_lat: float, new_lon: float)`:
  - `var new_mx = calculator.latToMeter(new_lat)`, `var new_my = calculator.lonToMeter(new_lon)`
  - `var delta_mx = origin_mx - new_mx`, `var delta_my = origin_my - new_my` — **old minus new**: positive when origin moves toward lower values, so chunk_roots shift the correct direction
  - Updates `origin_mx = new_mx`, `origin_my = new_my`
  - Calls `spawner.shift_all_roots(delta_mx, delta_my)` — SpawnManager shifts all chunk_root positions; no geometry is reloaded
- Update `drawDebugChunkOutline()` to iterate `loadedChunks` keys as `Vector2i` tiles and compute outlines directly from tile meter bounds minus origin:
  `Vector3(tile.x * CHUNK_M - origin_mx, 0, tile.y * CHUNK_M - origin_my)` → `Vector3((tile.x+1) * CHUNK_M - origin_mx, 0, (tile.y+1) * CHUNK_M - origin_my)`

**2b. SpawnManager.gd — chunk_root positioning and shift_all_roots**
- Compute tile center in absolute Web Mercator meters (same axis convention as origin_mx/my):
  `tile_center_mx = (tile.x + 0.5) * CHUNK_M`, `tile_center_my = (tile.y + 0.5) * CHUNK_M`
- Position each chunk_root at its tile center relative to the current floating origin:
  `chunk_root.position = Vector3(tile_center_mx - main.origin_mx, 0, tile_center_my - main.origin_my)`
- Pass `tile_center_mx` and `tile_center_my` to each spawner alongside `container` (see Phase 2c)
- Add `shift_all_roots(delta_mx: float, delta_my: float)` to SpawnManager: iterates all values in `_chunk_nodes` and applies `node.position += Vector3(delta_mx, 0, delta_my)`. Called by `main._recenter` with `delta = old_origin - new_origin`. Entity children inside each chunk_root are unaffected because their positions are relative to the chunk_root, not the world origin.

**2c. All spawner files — tile-relative entity positions**
- Add `tile_center_mx: float, tile_center_my: float` to every spawner's `handleData` signature:
  `handleData(data: Array, container: Node3D, tile_center_mx: float, tile_center_my: float)`
- Replace `main.latLonToCoordsInMeters(lat, lon)` with the direct tile-relative formula (preserving axis convention):
  `Vector2(main.calculator.latToMeter(lat) - tile_center_mx, main.calculator.lonToMeter(lon) - tile_center_my)`
  - Point spawners (trees, lights, hydrants, etc.): apply to each element's `lat`/`lon`
  - Polyline spawners (streets, rails): apply to each node in `element["geometry"]`
  - Polygon spawners (houses): apply to each vertex in `element["geometry"]`
- `groundSpawner.spawnGround(tile, chunk_root, tile_center_mx, tile_center_my)` — ground plane is centered at `(0, 0, 0)` relative to chunk_root (i.e., tile center), sized `CHUNK_M × CHUNK_M`
- Update all `handleData` / `spawnGround` call sites in `SpawnManager._processJson` to pass the computed tile_center values
- `latLonToCoordsInMeters` on `main` and `calculator` can be removed once all callers are migrated

---

### Phase 3 — Teleport without full flush

**3a. main.gd `setNewCenterPosition`**
- No longer calls `flush_all_instances` + `loadedChunks = {}`
- Instead calls `_recenter(lat, lon)` (shifts origin)
- Player is repositioned to the new tile's in-game 3D position
- Chunk streaming logic then naturally loads new chunks and unloads distant ones (Phase 4)

---

### Phase 4 — Render distance + streaming unload

**4a. main.gd**
- Add `var render_distance: int = 3` (in chunks)
- In `_process`, compute the set of tiles that should be loaded within `render_distance` of the player's current tile using **chessboard distance** (Chebyshev — diagonal neighbors count the same as cardinal ones, producing a square loaded area):
  ```
  var desired = []
  for dx in range(-render_distance, render_distance + 1):
      for dy in range(-render_distance, render_distance + 1):
          desired.append(player_tile + Vector2i(dx, dy))
  ```
- Tiles in `desired` but not in `loadedChunks` → `spawn_chunk(tile)`
- Tiles in `loadedChunks` but not in `desired` → `unload_chunk(tile)`

**4b. SpawnManager.gd**
- `_chunk_nodes` becomes a plain `Dictionary` keyed by `Vector2i` (tile → chunk_root); GDScript 4 typed Dictionary syntax does not support `Vector2i` as a key type, so use untyped `Dictionary`
- `_loading_chunk: Vector2` → `_loading_chunk: Vector2i`
- Add `unload_chunk(tile: Vector2i)`: frees the node, removes from dict
- `spawn_chunk` takes `Vector2i tile` instead of `Vector2 chunk`
- `onChunkLoaded(tile)` called with Vector2i

**4c. main.gd `loadedChunks`**
- Key: `Vector2i` tile (absolute)
- Value: `false` = loading, `true` = loaded

---

### Phase 5 — Render distance setting in pause menu

**5a. pause_menu.tscn**
- Add a HSlider (range 1–7) + Label "Render distance: N km" below the existing VBoxes

**5b. PauseMenuManager.gd**
- Connect slider `value_changed` → `main.render_distance = int(value)`
- Initialize slider from `main.render_distance`

---

## Relevant files
- `calculator.gd` — add `latLonToTile`, `metersToLatLon`, `CHUNK_M`; drop `_lat` from `lonToMeter`
- `main.gd` — floating origin, tile-based chunk tracking, streaming loop, recenter trigger
- `SpawnManager.gd` — tile-keyed cache, tile-based bbox, dict chunk_nodes, unload_chunk
- All spawners — entities relative to tile center (small change per spawner)
- `ui/pause_menu.tscn` + `PauseMenuManager.gd` — render distance slider

## Verification
1. Teleport to Stefansplatz, walk to adjacent chunk → chunk loads; teleport back to Gasometer → Stefansplatz cache hit (< 1 s)
2. Walk 3+ chunks away → old chunks unload (confirm in scene tree)
3. Move 5 km from origin → recenter fires, no visible pop (all geometry shifts smoothly)
4. Change render distance slider → chunks load/unload immediately
5. Cache files named `tile_6385_4991.json` (absolute) not relative coords

## Decisions
- Chunk identity: `Vector2i` absolute Web Mercator tile index, not relative to lat_center
- Chunk size: `CHUNK_M = 1000.0` meters (same as current chunk_size)
- Origin recentering: triggered at > 5000 m drift, smooth (no geometry reload)
- On teleport: origin shifts, geometry repositions, no full flush
- Render distance: configurable 1–7 chunks, default 3, stored on main.gd
- Unload criterion: chessboard (Chebyshev) distance from player tile > render_distance → square loaded area, no missing corners
