# Real World Simulator

Real World Simulator is a Godot 4 project that fetches OpenStreetMap (OSM) data through the Overpass API and turns it into a streamed 3D world. Choose a saved location or search for a place, then explore the generated streets, buildings, terrain, vegetation, and map objects in first-person or car mode.

## Features

- Fetches map data from Overpass
- Generates a 3D world from OSM features
- Streams nearby map data in 1 km chunks
- Caches downloaded chunks locally for seven days
- Searches for locations with Geoapify autocomplete
- Stores favorite and recently used locations locally
- Lets the player explore on foot or switch to an off-road car
- Supports a configurable render distance from 1 to 7 chunks

### World generation

The generator queries the following OSM features:

- `node[highway=street_lamp]` -> street lights
- `node[natural=tree]` -> trees
- `node[leisure=picnic_table]` -> picnic tables
- `node[amenity=waste_basket]` (excluding indoor bins) -> trash baskets
- `node[emergency=fire_hydrant]` -> fire hydrants
- `way[building]` -> building footprints
- `way[railway=rail]` -> rails
- `way[highway]`, `way[area:highway]`, and matching multipolygon relations -> roads
- `way` and multipolygon relations tagged with `landuse`, `natural`, or `surface` -> ground surfaces

Ground surfaces are classified as water, asphalt, concrete, gravel, dirt, industrial, residential, farmland, forest, or grass. Road width uses the OSM `width` or `lanes` tag when available and otherwise falls back to a width for the highway type. Unknown ground-surface tags fall back to grass.

Chunks are requested around the player in a square neighborhood. The default render distance is 3, which loads up to 49 chunks; the pause menu can change it from 1 to 7. The world uses Web Mercator coordinates and a floating origin, recentering when the player moves more than 5 km from the current origin.

## Requirements

- Godot 4.6 or later with the GL Compatibility renderer
- Internet connection for Overpass data and, if using place search, Geoapify autocomplete
- A Geoapify API key for searching locations (optional if using the built-in favorites)

## Getting Started

1. Clone this repository:
   ```bash
   git clone <repository-url>
   ```
2. Open the project in Godot.
3. Run `main.tscn` or press Play Project.
4. Open the pause menu, choose a favorite, or search for a location to move the world center.

### Geoapify setup

To enable place search, create `.secrets/geoapify_api_key.txt` in the project root and put the API key on one line. The `.secrets` directory is intended for local secrets and should not be committed. The key is used only for Geoapify's geocoding autocomplete endpoint; map geometry is fetched separately from Overpass.

## Controls

| Action | Input |
|---|---|
| Move | Arrow keys or `WASD` |
| Sprint | Hold `Shift` while moving |
| Look around | Mouse movement |
| Jump | `Space` |
| Toggle flashlight | `F` |
| Pause / location menu | `Esc` |
| Grab physics objects | `E` |
| Throw grabbed object | Left mouse button |

The default mode is fly-around first person. The pause menu also provides a car mode, which loads the off-road vehicle scene.

## Configuration

The main runtime settings are available from the pause menu:

- Location search, favorites, and recents
- Fly-around or car mode
- Render distance from 1 to 7 chunks

The initial world center is near Vienna, Austria (48.18574, 16.413616). Favorites and recents are saved to `user://teleport_places.json`. Downloaded Overpass responses are stored in `user://chunk_cache/` and expire after seven days. The cache schema is versioned in the generator so it can be invalidated when the query changes.

The Overpass endpoint and OSM query are defined in `SpawnManager.gd`. The Geoapify endpoint, result limit (10), and search debounce (0.3 seconds) are defined in `GeoapifySearch.gd`.

## Data and Attribution

Map data comes from OpenStreetMap contributors and is retrieved through the Overpass API. OSM data is available under the Open Database License (ODbL). Any public release or generated-world distribution should retain appropriate OpenStreetMap attribution and comply with the ODbL, including its share-alike and database notice requirements where applicable. Geoapify is used for place autocomplete when an API key is configured; follow Geoapify's current attribution and service terms for that use.

## Limitations

- Overpass requests require an internet connection unless the requested chunks are already cached.
- Large areas, high render distances, or complex queries may take longer to fetch and generate and may use more memory.
- OSM coverage and tagging determine which objects appear; missing or differently tagged features are not generated.
- The project currently uses a single active Overpass request and queues additional chunk loads.
- Geoapify search is unavailable without a valid API key, but saved and seeded locations remain available.

## Contributing

Contributions are welcome. Open an issue to report a bug or suggest an improvement, or submit a pull request.

## License

The project README declares an MIT license. A root-level license file is not currently present, so add one before distributing the project if the MIT terms are intended to be authoritative. The `addons/debug_draw_3d/LICENSE` file applies to that addon.