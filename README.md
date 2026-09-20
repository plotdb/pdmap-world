# pdmap-world

World map in D3js and ISO 3166 country code. 


## Usage

include required JS files:

    <script src="https://d3js.org/d3.v4.js"></script>
    <script src="https://d3js.org/topojson.v2.min.js"></script>
    <script src="path-to-your-pdmap-world.js"></script>

then, init with following:

    p = new pdmapWorld({ ... })
    p.init().then(function() {  p.fit();  ...  })


country paths will be added under a SVG `g` element with `pdmap-world` class. pdmap-world only draws countries. To further visualize your data, you have to do it yourself, such as:

    # if you call `p.set` first:   
    d3.select(root).selectAll("path")
      .attr "fill", (d,i) ~>
        v = d.properties.value or 0
        if v <= 0 => return \#eee
        "rgb(#{255 * (d.properties.value or 0) / p.range!},0,0)"

    # or bind data with country yourself:
    d3.select(root).selectAll("path")
      .attr "fill", (d,i) ~>
        v = data[d.properties.alpha2]
        if v <= 0 => return \#eee
        "rgb(#{255 * (v) / max},0,0)"


## Constructor options

 - `root`: container element.
 - `excludes`: Array of country identifiers ( see below ). countries listed here will not be shown.
 - `includes`: Array of country identifiers ( see below ). countries not listed here will not be shonw.
   - when `includes` is set, `excludes` will be ignored.
 - `padding`: padding space between container and map shapes.
 - `popup`: handler called when mouse hovering on shapes.


## API

 - `init()`: initialization.
 - `set(hash)`: set values for each country. country name as key in hash, value as value in hash.
 - `range()`: get `[minimal, maximal]` values from `set` calls.
 - `allCountries()`: get a list of all countries.
 - `fit()`: fix map to size of container.
 - `findCountry(n)`: return a country object according to country identifier `n` ( see below )
 - `mode([m][, {animate}])`: with no argument, returns the current mode; with `'dorling'` or `'choropleth'`, switches mode ( transition unless `{animate:false}` ).
 - `setDorlingOption(opt)`: merge/override dorling options at runtime and refresh ( e.g. toggle `basemap` / `gravity` / `link` ).
 - `setTooltipOption(opt)`: merge/override tooltip options at runtime ( e.g. `{enabled: false}` ).
 - `countryOfDatum(d)`: resolve a d3 datum to its country object, whichever mode it came from. Also available as `pdmapWorld.countryOfDatum(d)`.
 - `destroy()`: stop the force layout and detach the listeners and tooltip node this map added outside its root.


## Tooltip

Hovering a country can show a tooltip with its name and value. It is off by
default, since a host may well draw its own from `popup`; pass `{tooltip: true}`
to turn it on, or an object to configure it:

    p = new pdmapWorld({ root: "#root", tooltip: true })
    p = new pdmapWorld({ root: "#root", tooltip: { enabled: true, offset: 16 } })

 - `enabled` ( default `false` ).
 - `offset` ( default `12` ): px between the cursor and the tip box. The box flips to the other side near a viewport edge.
 - `class`: extra class on the tip node, for styling.
 - `format`: `(value, country) -> string` for the value line. Defaults to `d3.format(',')`.
 - `accessor`: `({evt, data, country}) -> {name, group, value, valueAlt}` to build the content yourself. Return `null` to show nothing for that target.

The tip node is a `div.pdmap-tip` on `document.body` holding `.pdmap-tip-name`,
`.pdmap-tip-group` and `.pdmap-tip-value` ( with an optional
`.pdmap-tip-value-alt` inside ). A default stylesheet is injected once, at low
specificity, so your own rules win.

The separate `popup` option is untouched: it still gets `{evt, data}` with the
raw datum on every hover.


## Datum per mode

Choropleth `<path>` carries the topojson feature while dorling `<circle>`
carries the country object, so an accessor that has to work in both modes should
go through `countryOfDatum`:

    d3.select(p.root).selectAll("path, circle")
      .attr("fill", function (d) {
        var c = pdmapWorld.countryOfDatum(d);
        return (c && c.value != null) ? scale(c.value) : "#eee";
      })


## Dorling cartogram

In `dorling` mode each country becomes a **circle** whose area is scaled from the value
given via `set()` ( a `sqrt` radius scale by default ), and `d3-force` pushes the circles
apart so they don't overlap. Enable it at construction or at runtime:

    p = new pdmapWorld({ root: "#root", mode: "dorling", dorling: { ... } })
    // or later:
    p.mode("dorling")   // p.mode("choropleth") to switch back; p.mode() to read

`dorling` options ( all optional ):

 - `basemap` ( default `true` ): draw a light, non-colored country outline layer as a geographic reference.
 - `gravity` ( default `'centroid'` ): `'centroid'` pulls each circle toward its own geographic centroid ( in current projection pixels ); `'center'` pulls all circles toward the screen center.
 - `link` ( default `false` ): draw a thin line from each circle back to its geographic centroid ( shows where the circle "came from" ).
 - `radius`: `{ auto, fillRatio, max, maxValue }`, or a function `value -> radius` to fully override the scale.
   - `auto` ( default `true` ): derive the largest radius from how much room the map actually has, instead of a fixed number. The circles are sized so that together they cover `fillRatio` of the map bounding box, which keeps the layout from overflowing when the values or the set of countries change.
   - `fillRatio` ( default `0.4` ): that share. Lower means smaller circles - less overlap, more empty space; higher means the opposite. This is the knob to trade overlap against crowding.
   - `max`: with `auto` on this is only an upper bound ( a hint ); with `auto` off it is the largest radius, verbatim.
   - `maxValue`: the value mapped to the largest radius ( defaults to the maximum of `range()` ).
 - `bounds` ( default `true` ): clamp circles into the map bounding box on every tick, so the layout never spills outside the chart. A circle wider than the box is centered instead.
 - `strength` ( default `0.15` ), `collidePadding` ( default `1.5` ), `transition` ( ms, default `500` ).
 - style overrides: `basemapFill`, `basemapStroke`, `basemapStrokeWidth`, `linkStroke`, `linkStrokeWidth`.

Requires `d3` **v7** in scope ( it bundles `d3-force`: `forceSimulation` / `forceX` / `forceY` / `forceCollide` )
plus global `topojson`. See `web/` for a demo of both modes with every switch wired up.


## Country Identifiers

There are many ways to identify a country. Here we use following identifiers:

 - iso 3166 country code, including:
   - Alpha-2 code ( e.g., `KP` for North Korea, `GB` for United Kingdon. )
   - Alpha-3 code ( e.g., `USA` for United States, `JPN` for Japan )
   - Short name ( e.g., `Afghanistan`, `Congo (the)` )
   - Numeric ( e.g., `156` for China, `524` for Nepal )
 - Common name in zh-TW ( e.g., `阿爾巴尼亞`, `波希尼亞及赫塞哥維那` )

Following is an example to refer some countries with a list, which can be used as `excludes` / `includes` option:

    ["KP", "USA", "Afghanistan", 156, "波希尼亞及赫塞哥維那"]

All codes are case insensitive.


## Data Resources

 - map data: [natural-earth-vector](https://github.com/nvkelso/natural-earth-vector)
 - country code: [iso 3166 country codes](https://www.iso.org/iso-3166-country-codes.html)


## License

 - Code: MIT
 - Data: 
   - map data: Public Domain
   - country code: should be(?) Public Domain
