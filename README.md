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
