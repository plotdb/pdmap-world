meta = require "./meta.json"
topo = require "./topo.json"
continent = require "./continent.json"

ne = d3.geoNaturalEarth1Raw

# name every transition we own. d3 cancels a *pending* transition when another
# one with the SAME name is scheduled on the element, so an unnamed transition
# here would be silently killed by a host doing its own
# `selectAll('circle').transition().attr('fill', ...)` right after `set()` -
# leaving the model updated but the radii stuck at their previous value.
tn = \pdmap

dorling-defaults =
  basemap: true
  gravity: \centroid   # 'centroid' ( toward geographic center ) or 'center' ( toward screen center )
  link: false
  strength: 0.15       # forceX / forceY strength toward gravity target
  collide-padding: 1.5 # extra spacing ( in projection units ) between circles
  transition: 500      # ms for mode / value transitions ; 0 to disable
  basemap-fill: \#e6e6e6
  basemap-stroke: \#cccccc
  basemap-stroke-width: 0.3
  link-stroke: \#999999
  link-stroke-width: 0.4
  bounds: true         # keep circles inside the map bounding box
  # { auto, fill-ratio, max, max-value } or a scale function ( value -> radius )
  radius: {}

tooltip-defaults =
  enabled: false       # opt-in: a host may well draw its own tip from `popup`
  offset: 12           # px between the cursor and the tip box
  class: ''            # extra class on the tip node, for styling
  format: null         # (value, country) -> string
  accessor: null       # ({evt, data, country}) -> {name, group, value, value-alt} or null

# low specificity on purpose, so a page can restyle the tip with its own rules.
tooltip-style = '''
.pdmap-tip {
  position: fixed; z-index: 2000; pointer-events: none;
  padding: .35em .6em; border-radius: 3px; white-space: nowrap;
  background: rgba(0,0,0,.78); color: #fff;
  font-size: 12px; line-height: 1.4;
}
.pdmap-tip-name { font-weight: 600 }
.pdmap-tip-group, .pdmap-tip-value-alt { opacity: .75 }
'''

esc = (v) ->
  "#v".replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

pdmap-world = (opt = {}) ->
  @root = if typeof(opt.root) == typeof('') => document.querySelector(opt.root) else opt.root
  @ <<< {excludes: opt.excludes or <[Antarctica]>, includes: opt.includes or []}
  @ <<< {features: [], path: null, wm: new WeakMap!, countries: []}
  @ <<< opt{popup, padding}
  @_mode = opt.mode or \choropleth
  @dorling-opt = {} <<< dorling-defaults <<< (opt.dorling or {})
  @tooltip-opt = {} <<< tooltip-defaults <<<
    if typeof(opt.tooltip) == typeof(true) => {enabled: opt.tooltip} else (opt.tooltip or {})
  @projection = d3.geoProjection (x,y) ->
    lat = y * 180 / Math.PI
    lng = x * 180 / Math.PI
    if lng < -160 and lat < 40 => lng += 20
    else if lng < -140 and lat < 40 => lng += 10
    x = lng * Math.PI / 180
    y = lat * Math.PI / 180
    return ne x, y
  @

pdmap-world.nametypes = <[name alpha2 alpha3 gapminder num shortname]>
pdmap-world.meta = meta
pdmap-world.topo = topo
pdmap-world._continent = continent
pdmap-world.prototype = Object.create(Object.prototype) <<< do
  find-country: (n) ->
    if meta.zhalpha2[n] => n = that
    if typeof(n) == \string => n = n.toLowerCase!
    for item in @countries => for key in pdmap-world.nametypes =>
      if item[key] == n or "#{item[key]}" == n => return item
    return null
  init: ->
    {root, popup} = @{root, popup}
    Promise.resolve!
      .then ~>
        @_on-move = (e) ~>
          n = e.target
          data = if n and n.nodeType == 1 => d3.select(n).datum! else null
          if data and popup? => popup {evt: e, data}
          @show-tooltip {evt: e, data, country: @country-of-datum data}
        @_on-leave = ~> @hide-tooltip!
        root.addEventListener \mousemove, @_on-move
        root.addEventListener \mouseleave, @_on-leave
        features = topojson.feature(topo, topo.objects["countries"]).features
        features.map (f) ~>
           idx = meta.num.indexOf(f.id)
           f.properties = obj = {}
           @wm.set obj, f
           pdmap-world.nametypes.map (n) -> obj[n] = meta[n][idx]
           @countries.push obj
        @excludes = @excludes
          .map ~> if ret = @find-country(it) => ret.num else null
          .filter -> it
        @includes = @includes
          .map ~> if ret = @find-country(it) => ret.num else null
          .filter -> it
        if @includes.length => @features = features = features.filter ~> (it.properties.num in @includes)
        else @features = features = features.filter ~> !(it.properties.num in @excludes)


        @path = path = d3.geoPath!.projection @projection
        node = if root.nodeName.toLowerCase! == \svg => d3.select(root)
        else if root.nodeName.toLowerCase! == \g => d3.select(root)
        else
          d3.select(root).append(\svg)
            ..attr \width, \100%
            ..attr \height, \100%
        @g = node.append(\g)
        @g.attr \class, \pdmap-world

        # layers ( stacking order fixed here ; populated lazily )
        @basemap-layer = @g.append(\g).attr(\class, \pdmap-basemap).style(\opacity, 0)
        @layer = @g.append(\g).attr(\class, \pdmap-choropleth)
        @link-layer = @g.append(\g).attr(\class, \pdmap-links).style(\opacity, 0)
        @dorling-layer = @g.append(\g).attr(\class, \pdmap-dorling).style(\opacity, 0).style(\pointer-events, \none)

        # choropleth country polygons ( original behavior )
        @layer
          .selectAll \path .data features
            ..exit!remove!
            ..enter!append \path
              .attr \d, path

        # precompute geographic centroids ( projection pixel coords ) + layout bounds
        features.map (f) ~> f.properties.geocenter = @path.centroid f
        b = @path.bounds {type: \FeatureCollection, features: features}
        @_bounds = b
        @_center = [(b.0.0 + b.1.0) / 2, (b.0.1 + b.1.1) / 2]
        [bw, bh] = [b.1.0 - b.0.0, b.1.1 - b.0.1]
        @_default-max-r = Math.min(bw, bh) / 12

        @_ticked = ~>
          if @dorling-opt.bounds => @clamp-nodes!
          if @circle-sel => @circle-sel.attr(\cx, (c) -> c._node.x).attr(\cy, (c) -> c._node.y)
          if @dorling-opt.link and @link-sel =>
            @link-sel.attr(\x1, (c) -> c._node.x).attr(\y1, (c) -> c._node.y)

        if @_mode == \dorling => @mode \dorling, {animate: false}
        else @apply-mode false

  fit: (rbox) ->
    rbox = rbox or @root.getBoundingClientRect!
    bbox = @g.node!getBBox!
    [width,height] = [rbox.width,rbox.height]
    padding = if @padding? => @padding else 0
    scale = Math.min((width - 2 * padding) / bbox.width, (height - 2 * padding) / bbox.height)
    [w,h] = [width / 2, height / 2]
    @g.attr(
      \transform,
      "translate(#w,#h) scale(#scale) translate(#{-bbox.x - bbox.width/2},#{-bbox.y - bbox.height/2})"
    )

  set: (o = {}) ->
    for k,v of o =>
      country = @find-country k
      if !country => continue
      country.value = v
    if @_mode == \dorling and @_dorling-ready =>
      @update-dorling!
      @start-sim!
    @

  range: ->
    [min,max] = [undefined,undefined]
    for c in @countries =>
      v = c.value
      if v > max or !(max?) => max = v
      if v < min or !(min?) => min = v
    return [min, max]
  all-countries: ->
    if @includes.length => @countries.filter ~> it.num in @includes
    else @countries.filter ~> !(it.num in @excludes)

  # ---- tooltip -------------------------------------------------------------

  # choropleth <path> carries the topojson feature while dorling <circle>
  # carries the country object. this resolves either to the country object.
  country-of-datum: (d) -> pdmap-world.country-of-datum d

  # merge in / override tooltip options at runtime.
  set-tooltip-option: (o = {}) ->
    @tooltip-opt = {} <<< @tooltip-opt <<< o
    if @tip-node => @tip-node.className = "pdmap-tip #{@tooltip-opt.class or ''}".trim!
    if !@tooltip-opt.enabled => @hide-tooltip!
    @

  ensure-tip: ->
    if @tip-node => return @tip-node
    if !document.getElementById(\pdmap-world-tip-style) =>
      node = document.createElement \style
      node.id = \pdmap-world-tip-style
      node.textContent = tooltip-style
      document.head.appendChild node
    @tip-node = node = document.createElement \div
    node.className = "pdmap-tip #{@tooltip-opt.class or ''}".trim!
    node.style.display = \none
    document.body.appendChild node
    node

  # what to put in the tip. override wholesale with `tooltip.accessor`.
  tip-content: (o = {}) ->
    if @tooltip-opt.accessor => return @tooltip-opt.accessor o
    if !(c = o.country) => return null
    fmt = @tooltip-opt.format or (v) ->
      if !(v?) => '-'
      else if typeof(v) != \number or isNaN(v) => "#v"
      else if d3.format => d3.format(',')(v)
      else "#v"
    # `shortname` is the presentable one ( "United States" ), `name` is the full
    # lowercase ISO label ( "united states of america (the)" ).
    {name: (c.shortname or c.name or c.alpha3 or ''), value: fmt(c.value, c)}

  show-tooltip: (o = {}) ->
    if !@tooltip-opt.enabled => return @hide-tooltip!
    if !(content = @tip-content o) => return @hide-tooltip!
    node = @ensure-tip!
    html = ''
    if content.name? => html += "<div class=\"pdmap-tip-name\">#{esc content.name}</div>"
    if content.group => html += "<div class=\"pdmap-tip-group\">#{esc content.group}</div>"
    if content.value? =>
      alt = if content.value-alt =>
        " <span class=\"pdmap-tip-value-alt\">#{esc content.value-alt}</span>"
      else ''
      html += "<div class=\"pdmap-tip-value\">#{esc content.value}#{alt}</div>"
    node.innerHTML = html
    node.style.display = \block
    @place-tooltip o.evt
    @

  # follow the cursor, flipping to the other side near a viewport edge.
  place-tooltip: (evt) ->
    if !(@tip-node and evt and evt.client-x?) => return @
    box = @tip-node.getBoundingClientRect!
    gap = @tooltip-opt.offset
    x = evt.client-x + gap
    y = evt.client-y + gap
    if x + box.width > window.innerWidth => x = evt.client-x - gap - box.width
    if y + box.height > window.innerHeight => y = evt.client-y - gap - box.height
    @tip-node.style.left = "#{Math.max 0, x}px"
    @tip-node.style.top = "#{Math.max 0, y}px"
    @

  hide-tooltip: ->
    if @tip-node => @tip-node.style.display = \none
    @

  # drop everything this map attached outside its own root.
  destroy: ->
    if @sim => @sim.stop!
    if @root and @_on-move =>
      @root.removeEventListener \mousemove, @_on-move
      @root.removeEventListener \mouseleave, @_on-leave
    if @tip-node and @tip-node.parentNode => @tip-node.parentNode.removeChild @tip-node
    @tip-node = null
    @

  # ---- Dorling cartogram ---------------------------------------------------

  # get current mode, or switch to 'dorling' / 'choropleth'.
  # opt.animate ( default true ) toggles the transition.
  mode: (m, opt = {}) ->
    if !(m?) => return @_mode
    if m not in <[dorling choropleth]> => return @
    animate = if opt.animate? => opt.animate else true
    @_mode = m
    if !@g => return @   # not initialized yet ; init will apply
    if m == \dorling =>
      @setup-dorling!
      @update-dorling!
      @start-sim!
    else if @sim => @sim.stop!
    @apply-mode animate
    @

  # merge in / override dorling options at runtime, then refresh if active.
  set-dorling-option: (o = {}) ->
    @dorling-opt = {} <<< @dorling-opt <<< o
    if @basemap-layer =>
      @basemap-layer.selectAll(\path)
        .attr(\fill, @dorling-opt.basemap-fill).attr(\stroke, @dorling-opt.basemap-stroke)
    if @_mode == \dorling and @_dorling-ready =>
      @update-dorling!
      @start-sim!
      @apply-mode false
    @

  # pull every circle back inside the map bounding box. a circle wider than the
  # box itself is centered instead of clamped.
  clamp-nodes: ->
    if !(@_nodes and @_bounds) => return
    [[x0, y0], [x1, y1]] = @_bounds
    for n in @_nodes =>
      if x1 - x0 <= 2 * n.r => n.x = (x0 + x1) / 2
      else n.x = Math.max (x0 + n.r), Math.min((x1 - n.r), n.x)
      if y1 - y0 <= 2 * n.r => n.y = (y0 + y1) / 2
      else n.y = Math.max (y0 + n.r), Math.min((y1 - n.r), n.y)
    @

  # largest radius whose circles together cover `fill-ratio` of the map bounding
  # box. this is what keeps the layout from overflowing / turning into one blob
  # when the values ( or the number of countries ) change.
  area-fit-radius: (max-value) ->
    o = @dorling-opt.radius or {}
    fill = if o.fill-ratio? => o.fill-ratio else 0.4
    if !(fill > 0) or !(max-value > 0) or !@_bounds => return null
    [[x0, y0], [x1, y1]] = @_bounds
    area = (x1 - x0) * (y1 - y0)
    sum = 0
    for c in @all-countries! => if c.value > 0 => sum += c.value
    if !(area > 0) or !(sum > 0) => return null
    # r(v) = R * sqrt(v / max-value), so the circles cover PI * R^2 * sum / max-value
    r = Math.sqrt fill * area * max-value / (Math.PI * sum)
    # a handful of countries can ask for a circle wider than the map itself.
    Math.min r, Math.min(x1 - x0, y1 - y0) / 2

  build-radius-scale: ->
    o = @dorling-opt.radius or {}
    if typeof(o) == \function => return o
    [mn, mx] = @range!
    max-value = if o.max-value? => o.max-value else (mx or 1)
    max-r = if o.max? => o.max else @_default-max-r
    # with `auto` on, `max` is only an upper bound - the real radius comes from
    # how much room the map actually has.
    if (if o.auto? => o.auto else true) =>
      if (r = @area-fit-radius max-value)? =>
        max-r = if o.max? => Math.min o.max, r else r
    d3.scaleSqrt!.domain([0, max-value or 1]).range([0, max-r])

  setup-dorling: ->
    if @_dorling-ready => return
    @_dorling-ready = true
    @basemap-layer.selectAll(\path).data(@features).enter!append(\path)
      .attr \d, @path
      .attr \fill, @dorling-opt.basemap-fill
      .attr \stroke, @dorling-opt.basemap-stroke
      .attr \stroke-width, @dorling-opt.basemap-stroke-width
      .attr \class, \pdmap-basemap-country
      .style \pointer-events, \none

  update-dorling: ->
    if !@_dorling-ready => return
    @radius-scale = @build-radius-scale!
    old = @_node-map or {}
    nm = {}
    nodes = []
    list = []
    for c in @all-countries! =>
      v = c.value
      if !(v?) => continue
      r = @radius-scale v
      if !(r > 0) => continue
      [gx, gy] = c.geocenter
      if !(gx? and gy?) => continue
      prev = old[c.num]
      node = if prev? => prev else {}
      node <<< {r: r, gx: gx, gy: gy}
      if !(node.x?) => node.x = gx
      if !(node.y?) => node.y = gy
      if @dorling-opt.gravity == \center =>
        node.tx = @_center.0
        node.ty = @_center.1
      else
        node.tx = gx
        node.ty = gy
      c._node = node
      node.country = c
      nm[c.num] = node
      nodes.push node
      list.push c
    @_node-map = nm
    @_nodes = nodes
    t = if @dorling-opt.transition => @dorling-opt.transition else 0

    # circles ( datum = country object, same as choropleth paths )
    sel = @dorling-layer.selectAll(\circle).data(list, (c) -> c.num)
    sel.exit!remove!
    @circle-sel = sel.enter!append(\circle)
      .attr \cx, (c) -> c._node.x
      .attr \cy, (c) -> c._node.y
      .attr \r, 0
      .attr \class, \pdmap-dorling-circle
      .merge sel
    @circle-sel.transition(tn).duration(t).attr \r, (c) -> c._node.r

    # relation lines from circle center to geographic centroid
    lsel = @link-layer.selectAll(\line).data(list, (c) -> c.num)
    lsel.exit!remove!
    @link-sel = lsel.enter!append(\line)
      .attr \class, \pdmap-link
      .attr \stroke, @dorling-opt.link-stroke
      .attr \stroke-width, @dorling-opt.link-stroke-width
      .style \pointer-events, \none
      .merge lsel
    @link-sel
      .attr \x1, (c) -> c._node.x
      .attr \y1, (c) -> c._node.y
      .attr \x2, (c) -> c._node.gx
      .attr \y2, (c) -> c._node.gy

  start-sim: ->
    if !@_nodes => return
    if !d3.forceSimulation =>
      console.warn 'pdmap-world: d3.forceSimulation not found; circles stay at geographic centroids.'
      @_ticked!
      return
    if @sim => @sim.stop!
    o = @dorling-opt
    @sim = d3.forceSimulation(@_nodes)
      .force \x, d3.forceX((d) -> d.tx).strength(o.strength)
      .force \y, d3.forceY((d) -> d.ty).strength(o.strength)
      .force \collide, d3.forceCollide((d) -> d.r + o.collide-padding).strength(0.85).iterations(2)
      .on \tick, @_ticked
      .alpha 1 .restart!

  apply-mode: (animate) ->
    if !@g => return
    d = @_mode == \dorling
    t = if animate and @dorling-opt.transition => @dorling-opt.transition else 0
    @layer
      ..style \pointer-events, (if d => \none else \auto)
      ..transition(tn).duration(t).style \opacity, (if d => 0 else 1)
    if @basemap-layer =>
      @basemap-layer.transition(tn).duration(t).style \opacity, (if (d and @dorling-opt.basemap) => 1 else 0)
    if @link-layer =>
      @link-layer.transition(tn).duration(t).style \opacity, (if (d and @dorling-opt.link) => 1 else 0)
    if @dorling-layer =>
      @dorling-layer
        ..style \pointer-events, (if d => \auto else \none)
        ..transition(tn).duration(t).style \opacity, (if d => 1 else 0)

pdmap-world.country-of-datum = (d) ->
  if !d => return null
  c = if d.properties? => d.properties else d
  if c and c.num? => c else null

pdmap-world.continent-of = (name) ->
  for n in pdmap-world.nametypes =>
    if !~(idx = meta[n].indexOf(name)) => continue
    return continent.names[continent.map[idx]] or 'unknown'
  return 'unknown'

if module? => module.exports = pdmap-world
else if window? => window.pdmap-world = pdmap-world
