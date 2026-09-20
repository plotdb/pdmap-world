# Change Logs

## v0.0.6

 - add **Dorling cartogram** mode: countries render as value-scaled circles laid out with `d3-force`.
   - `mode('dorling'|'choropleth')` / constructor `{mode}` to switch (smooth transition).
   - `dorling` option group: `basemap` (light reference outlines), `gravity` (`'centroid'|'center'`), `link` (line from circle back to its geographic centroid), plus `radius`, `strength`, `collidePadding`, `transition`, and style overrides.
   - circle sizing adapts to the space available: `radius.auto` ( default on ) picks the largest radius so the circles cover `radius.fillRatio` ( default `0.4` ) of the map bounding box, with `radius.max` demoted to an upper-bound hint. `radius.fillRatio` is the overlap-vs-crowding knob.
   - `bounds` ( default `true` ) keeps circles inside the map bounding box.
   - `setDorlingOption(opt)` to toggle switches at runtime; `mode()` (no arg) returns current mode.
   - dorling circles carry the country object as their datum while choropleth paths still carry the topojson feature.
   - uses global `d3` (v7 bundles d3-force) and `topojson`; no new dependencies.
 - internal: country polygons moved into a `g.pdmap-choropleth` layer; new sibling layers `g.pdmap-basemap`, `g.pdmap-links`, `g.pdmap-dorling`.

## v0.0.5

 - add `main` and `browser` field in `package.json`.
 - further minimize generated js file with mangling and compression
 - speed up building by using script directly instead of `npx`
 - upgrade modules
 - patch test code to make it work with upgraded modules
 - release with compact directory structure


## v0.0.4

 - add continent information and tools


## v0.0.3

 - by default excludes `Antarctica`
 - support rendering inside an `g` element.
 - upgrade modules.


## v0.0.2

 - export `meta` and `topo` with `pdmapWorld`.

