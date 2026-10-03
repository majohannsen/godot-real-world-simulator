## Plan: Teleport Search, Recents, Favorites

Replace static teleport buttons with a dynamic place workflow in the pause menu: Geoapify Autocomplete live search (debounced), persistent recents (teleported places only), and persistent favorites. Teleport execution will continue to use your current world recenter flow so gameplay behavior stays stable.

**Steps**
1. Phase 1: Define a unified place data shape used everywhere (search results, recents, favorites): id, name, address, city, country, lat, lon, source, last_used_unix. Use Geoapify place_id as id.
2. Add a persistence layer that stores recents and favorites in user://teleport_places.json using FileAccess. Include load, save, add/remove favorite, add recent, dedupe by id only, and ordering logic. Persist only places that have a non-empty id.
3. Seed first-run favorites from your current static places (Gasometer, Stefansplatz, Lustenau, Karlsplatz, Vienna Hbf), then stop using hardcoded location buttons.
4. Apply agreed limits: recents capped to 20, favorites uncapped, search results capped to top 10.
5. Phase 2: Add a Geoapify search service using only the Geoapify Autocomplete endpoint (/v1/geocode/autocomplete) with limit=10 and apiKey, plus HTTPRequest lifecycle management, stale-response protection, and normalized parsing for name/address/city-country.
6. Wire live search with debounce (around 300 ms) from LineEdit text changes; only latest request updates UI.
7. Add lightweight in-memory query cache for repeated typing sessions.
8. Phase 3: Refactor pause menu layout to include search input + three dynamic sections: Favorites, Recents, Search Results. Keep player mode and render-distance controls unchanged.
9. Use a reusable row UI pattern for each place entry with Teleport and Favorite toggle actions.
10. Phase 4: Refactor pause menu controller to generic handlers (search changed, render lists, toggle favorite, teleport selected place) and remove one-function-per-static-button logic.
11. Keep teleport mechanics exactly through existing recenter APIs, then on successful teleport: update recents, persist, refresh lists, hide menu.
12. Phase 5: Add empty-state and error-state UX (missing API key, network/rate-limit failure) without breaking the rest of the pause menu.
13. Phase 6: Validate behavior with runtime manual tests and restart persistence checks.
14. Tell the user exactly where to add the API key: set the exported geoapify_api_key field on the PauseMenu node in the Inspector.

**Relevant files**
1. [PauseMenuManager.gd](PauseMenuManager.gd): replace static location wiring with dynamic search/recents/favorites orchestration and exported API key field.
2. [ui/pause_menu.tscn](ui/pause_menu.tscn): replace static location button column with search field and dynamic list sections.
3. [main.gd](main.gd): reuse existing setNewCenterPosition flow unchanged.
4. [PlayerManager.gd](PlayerManager.gd): reuse existing setPlayerPositionOnZero behavior unchanged.
5. [SpawnManager.gd](SpawnManager.gd): reuse robust HTTP/caching patterns as implementation reference.
6. New files to add during implementation: GeoapifySearch.gd, PlaceStore.gd, ui/place_row.tscn, and ui/PlaceRow.gd.

**Verification**
1. Search triggers only after typing pause (debounced), not on every keystroke.
2. Search rows show name, address, and city/country when available.
3. Teleport from search/favorites rec enters world correctly and menu closes.
4. Recents only include teleported places, are deduplicated by id only, newest-first, max 20.
5. Favorites persist across restart and remain uncapped.
6. Initial static places appear as default favorites only once (first-run seed).
7. Missing/invalid API key and request failures show non-blocking UI feedback.
8. Older search responses never overwrite newer search results.
9. Places without id can be teleported to but are not saved in recents/favorites.

**Decisions captured**
1. Live search while typing (debounced).
2. Recents = teleported places only.
3. Recents and favorites persist across restarts.
4. Static buttons replaced, with those places moved into default favorites.
5. Geoapify API key provided as exported script variable in Inspector.
6. Limits: recents 20, favorites uncapped, top 10 search results.
7. Search uses Geoapify Autocomplete only.
8. Recents/favorites dedupe uses id only.
