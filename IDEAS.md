# Feature Ideas

A collection of possible improvements. These ideas are suggestions and are not commitments to implement them.

## Status Legend
- 💡 Idea
- 💬 Under discussion
- 📋 Planned
- ✅ Implemented
- 💤 Deferred

## Ideas

### [💡 Idea] Add openings in generated buildings for roads
- **Problem / Need:** In some places, roads run through generated buildings. Currently, the building covers the road, making that section disappear.
- **Proposal:** When a road passes through a building, create a matching opening in the building geometry so the road remains visible and accessible.
- **Benefit:** Roads and paths appear continuous on the generated map, including where they pass through or under buildings.
- **Examples:** A covered passageway, a path between parts of a building, or a tunnel through a building.
- **Open Questions:** Should the opening follow the exact road shape, or include an additional margin? Should certain road or path types be excluded?
- **Priority:** Not yet assessed
- **Discussion / Issue:** —

### [💡 Idea] Render bridges and grade-separated road crossings on separate levels
- **Problem / Need:** When two roads cross but one passes over the other as a bridge, the crossing is currently rendered like a regular at-grade intersection.
- **Proposal:** Render the roads at separate elevations based on their bridge, tunnel, and layer information. This should allow the lower road to continue underneath the bridge without appearing to connect to it.
- **Benefit:** Grade-separated crossings look more realistic, and road connections are represented correctly.
- **Examples:** A bridge crossing over a road, an elevated highway over a local street, or a road passing through a tunnel beneath another road.
- **Open Questions:** Which OSM tags should determine the vertical levels? How should crossings be handled when level information is missing or incomplete?
- **Priority:** Not yet assessed
- **Discussion / Issue:** —

### [💡 Idea] Generate roof shapes from building tags
- **Problem / Need:** Buildings currently have flat roofs, regardless of the roof information available in their OSM tags.
- **Proposal:** Read the roof-related building tags and use them to generate the corresponding roof shape.
- **Benefit:** Buildings would better reflect their mapped appearance and have more visual variety.
- **Examples:** Generate gabled, hipped, or flat roofs based on the tags.
- **Open Questions:** Which roof tags should be supported initially, and what fallback should be used when roof information is missing?
- **Priority:** Potentially a relatively small change
- **Discussion / Issue:** —

### [💡 Idea] Generate terrain geometry from elevation data
- **Problem / Need:** The generated terrain currently does not use real-world elevation data, so its shape may not match the actual landscape.
- **Proposal:** Use a freely available elevation dataset to create terrain geometry. For a global baseline, consider Copernicus DEM GLO-30. Use an open-source tool or library such as GDAL to load, reproject, and crop the raster to the project area, then sample elevation values to generate the terrain mesh.
- **Benefit:** The generated terrain would better reflect real-world hills, valleys, and slopes.
- **Possible Data Source:** Copernicus DEM GLO-30, which provides free global coverage at 30-meter resolution. Higher-resolution open datasets could be supported for specific regions where available.
- **Open Questions:** Should the terrain use a Digital Terrain Model (bare ground) or a Digital Surface Model (which may include buildings and vegetation)? How should missing data, coordinate systems, vertical datums, and different source resolutions be handled? What attribution is required when distributing the data or generated terrain?
- **Priority:** Not yet assessed
- **Discussion / Issue:** —

### [💡 Idea] Render tree rows
- **Problem / Need:** Tree rows mapped in OSM are not currently rendered, so these features are missing from the generated scene.
- **Proposal:** Render ways tagged `natural=tree_row` as rows of trees.
- **Benefit:** The generated scene would better represent tree-lined roads, field boundaries, and other mapped rows of trees.
- **Examples:** A line of trees along a road or a windbreak at the edge of a field.
- **Open Questions:** How should tree spacing, height, and appearance be determined when the OSM data does not specify them?
- **Priority:** Potentially a small change
- **Discussion / Issue:** —

### [💡 Idea] Render needle-leaved trees with a separate 3D model
- **Problem / Need:** Individual trees are already rendered, but they all use the broadleaved tree model. Needle-leaved trees therefore look like broadleaved trees.
- **Proposal:** Add a separate 3D model for needle-leaved trees. When a tree has the OSM tag `leaf_type=needleleaved`, render it with that model; otherwise, keep using the current model.
- **Benefit:** Rendered trees would better reflect the types of trees mapped in OSM.
- **Examples:** Render a tagged spruce or pine as a needle-leaved tree instead of a broadleaved tree.
- **Open Questions:** What should happen when the `leaf_type` tag is missing or has another value, such as `mixed`?
- **Priority:** Potentially a small change
- **Discussion / Issue:** —

### [💡 Idea] Render forest areas as groups of individual trees
- **Problem / Need:** Forest areas are not currently represented as individual trees, so they may look flat or lack detail in the generated scene.
- **Proposal:** Populate mapped forest areas with individual 3D tree objects, placing them within the area boundaries.
- **Benefit:** Forests would look more detailed and consistent with the rendering of individual trees.
- **Examples:** Render a mapped woodland as a group of trees rather than a flat surface.
- **Open Questions:** How should tree density and species be determined when the map data does not specify them? How can tree placement avoid roads, buildings, and other mapped features while keeping rendering performance acceptable?
- **Priority:** Not yet assessed
- **Discussion / Issue:** —

### [💡 Idea] Add exterior windows to each building floor
- **Problem / Need:** Buildings can have information about their number of floors, but their exterior walls are currently rendered without windows.
- **Proposal:** Use the number of floors to place rows of windows on the outside walls of each building.
- **Benefit:** Buildings would look more detailed and visually realistic.
- **Examples:** A three-story building could have three rows of windows on each suitable façade.
- **Open Questions:** How should window size and spacing be determined? Should buildings with mapped window information use that data, with a procedural layout as a fallback?
- **Priority:** Not yet assessed
- **Discussion / Issue:** —


## Deferred Ideas

Ideas that are not currently being pursued but may be reconsidered later.

- **Idea:** …
  - **Reason for deferral:** …

## Implemented Ideas

Optionally, list completed ideas here or link to the relevant issues or releases.

- **Idea:** …
  - **Implemented in:** …
