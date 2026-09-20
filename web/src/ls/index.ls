# pdmap-world demo + smoke tests.
#
# note: the two modes carry different datum types - choropleth <path> holds the
# topojson feature, dorling <circle> holds the country object - so anything that
# reads a datum goes through `countryOfDatum`.

$ = (s) -> document.querySelector s

# the library paints through d3 transitions, which only advance on animation
# frames. flushing d3's timer queue lets the tests read final values right away
# ( and keeps them working in a backgrounded tab, where rAF is throttled ).
flush = -> if d3.timerFlush => d3.timerFlush!

# the force layout keeps moving circles after fit(), so re-fit once it settles.
refit-on-settle = (p) -> if p.sim => p.sim.on \end, -> p.fit!

paint = (p, scale = d3.interpolateYlGnBu) ->
  max = p.range!1 or 1
  fill = (d) ->
    c = pdmap-world.country-of-datum d
    v = if c => c.value else null
    if !(v?) or v <= 0 => \#eee else scale v / max
  node = d3.select p.root
  node.select \.pdmap-choropleth .selectAll \path .attr \fill, fill
  node.select \.pdmap-dorling .selectAll \circle .attr \fill, fill
  p

random-data = (p) ->
  data = {}
  p.all-countries!map -> data[it.num] = Math.round(Math.random! * 100)
  data

world = {}

# both maps are driven by the same control panel, so the same settings can be
# compared on a 170-country layout and on a 6-country one.
maps = []
each = (fn) -> maps.map (m) -> fn m.p, m
repaint = -> maps.map (m) -> paint m.p, m.scale


#############################################################################
# left: the whole world. right: the `includes` subset. both start in the same
# mode and share one control panel, so they stay comparable at every step.
#############################################################################

# the defaults here have to match the initial state of the controls below.
dorling-opt = ->
  {basemap: true, gravity: \centroid, link: false, transition: 600, bounds: true}

Promise.resolve!
  .then ->
    world.left = new pdmap-world do
      root: '#root-left'
      tooltip: true
      dorling: dorling-opt!
    world.left.init!
  .then ->
    maps.push {p: world.left, scale: d3.interpolateYlGnBu}
    world.right = new pdmap-world do
      root: '#root-right'
      includes: <[china mongolia taiwan japan kr kp]>
      tooltip: true
      dorling: dorling-opt!
    world.right.init!
  .then ->
    maps.push {p: world.right, scale: d3.interpolateRainbow}
    each (p) ->
      p.set random-data p
      p.fit!
      refit-on-settle p
    repaint!

    $ '#mode-toggle' .addEventListener \click, ->
      mode = if world.left.mode! == \dorling => \choropleth else \dorling
      each (p) ->
        p.mode mode
        refit-on-settle p
      repaint!
      @textContent = "switch to #{if mode == \dorling => \choropleth else \dorling}"

    $ '#reroll' .addEventListener \click, ->
      each (p) -> p.set random-data p
      repaint!

    switch-ctrl = (id, key) ->
      $ "##{id}" .addEventListener \change, ->
        v = if @type == \checkbox => @checked else @value
        each (p) ->
          o = {}
          o[key] = v
          p.set-dorling-option o

    $ '#opt-tooltip' .addEventListener \change, ->
      each (p) ~> p.set-tooltip-option enabled: @checked

    switch-ctrl \opt-basemap, \basemap
    switch-ctrl \opt-link, \link
    switch-ctrl \opt-bounds, \bounds
    switch-ctrl \opt-gravity, \gravity

    range-ctrl = (id, key, fmt) ->
      label = $ "##{id}-value"
      $ "##{id}" .addEventListener \input, ->
        v = parseFloat @value
        label.textContent = fmt v
        each (p) ->
          o = {}
          o[key] = v
          p.set-dorling-option o
        repaint!

    range-ctrl \opt-strength, \strength, (v) -> v.toFixed 2
    range-ctrl \opt-collide, \collidePadding, (v) -> v.toFixed 1

    # `radius` is a group, so it always has to be submitted as a whole.
    apply-radius = ->
      max = parseFloat $('#opt-radius').value
      fill = parseFloat $('#opt-fill').value
      $ '#opt-radius-value' .textContent = if max > 0 => "#max" else \none
      $ '#opt-fill-value' .textContent = fill.toFixed 2
      each (p) ->
        p.set-dorling-option radius:
          auto: $('#opt-auto').checked
          fill-ratio: fill
          max: if max > 0 => max else void
      repaint!

    for id in <[#opt-auto #opt-fill #opt-radius]>
      $ id .addEventListener (if id == \#opt-auto => \change else \input), apply-radius


#############################################################################
# smoke tests, on a throwaway offscreen instance so the demos stay interactive.
#############################################################################

results = []
ok = (name, pass, detail = '') -> results.push {name, pass: !!pass, detail}
render = ->
  node = $ '#tests'
  node.innerHTML = ''
  results.map (r) ->
    li = document.createElement \li
    li.className = if r.pass => \text-success else \text-danger
    li.textContent = "#{if r.pass => '✓' else '✗'} #{r.name}#{if r.detail => " ( #{r.detail} )" else ''}"
    node.appendChild li
  n = results.filter(-> it.pass).length
  li = document.createElement \li
  li.className = "mt-1 #{if n == results.length => \text-success else \text-danger}"
  li.textContent = "#n / #{results.length} passed"
  node.appendChild li

# a map the tests can drive without disturbing the two on screen.
offscreen-svg = (id) ->
  box = document.createElement \div
  box.setAttribute \style, 'position:absolute;left:-9999px;top:0;width:480px;height:320px;'
  box.innerHTML = "<svg id=\"#id\" style=\"width:100%;height:100%\"></svg>"
  document.body.appendChild box
  box.firstChild

# is an `attr.r` tween still scheduled on this node, or did something cancel it?
r-tween-alive = (el) ->
  if !(t = el.__transition) => return false
  Object.keys(t)
    .filter -> it != \active
    .some (k) -> t[k].tween.some (x) -> x.name == \attr.r

opacity = (p, cls) -> parseFloat d3.select(p.root).select(cls).style(\opacity)
radii = (p) ->
  o = {}
  d3.select p.root .select \.pdmap-dorling .selectAll \circle .each (d) ->
    o[d.alpha2] = parseFloat this.getAttribute \r
  o

# 4x the value should give 2x the radius, given the default sqrt scale.
values = {tw: 100, jp: 64, us: 25, de: 4}

Promise.resolve!
  .then ->
    world.test = new pdmap-world root: offscreen-svg(\root-test), dorling: {transition: 0}
    world.test.init!
  .then ->
    p = world.test
    p.fit!
    node = d3.select p.root

    ok 'mode() defaults to choropleth', p.mode! == \choropleth, p.mode!
    ok 'tooltip is off unless asked for', p.tooltip-opt.enabled == false
    for cls in <[.pdmap-basemap .pdmap-choropleth .pdmap-links .pdmap-dorling]>
      ok "layer #cls exists", !node.select(cls).empty!

    # only countries carrying a value become circles
    p.set values
    p.mode \dorling, {animate: false}
    paint p
    flush!
    ok 'mode() switches to dorling', p.mode! == \dorling
    circles = node.select \.pdmap-dorling .selectAll \circle
    ok 'one circle per valued country', circles.size! == Object.keys(values).length,
      "#{circles.size!} circles"
    datum = if circles.size! => d3.select(circles.nodes!0).datum! else null
    ok 'circle datum is the country object', !!(datum and datum.num? and datum.value?)

    rs = radii p
    ok 'radius grows with value', rs.tw > rs.jp > rs.us > rs.de,
      <[tw jp us de]>.map(-> "#it:#{(rs[it] or 0).toFixed 1}").join ' '
    ok 'radius follows a sqrt scale', Math.abs(rs.tw / rs.us - 2) < 0.01,
      "tw/us = #{(rs.tw / rs.us).toFixed 3}"

    # set() while in dorling mode has to re-layout in place
    p.set {tw: values.de}
    flush!
    r2 = (radii p).tw
    ok 'set() updates radii in place', 0 < r2 < rs.tw, "#{r2.toFixed 1} < #{rs.tw.toFixed 1}"
    p.set values
    flush!

    # d3 cancels a *pending* transition when another one with the same name is
    # scheduled on the element. a host painting the circles with its own
    # ( unnamed ) transition right after set() would kill the library's radius
    # transition, leaving the model updated but the rendered radii stale.
    # only shows up with a non-zero duration, while the radius tween is pending.
    p.set-dorling-option transition: 300
    p.set {tw: values.de, de: values.tw}
    d3.select(p.root).selectAll(\circle).transition!duration(350).attr \fill, \#123456
    flush!
    ok 'a host transition on the circles does not cancel the radius update',
      d3.select(p.root).select(\.pdmap-dorling).selectAll(\circle).nodes!.every(r-tween-alive),
      "#{d3.select(p.root).select(\.pdmap-dorling).selectAll(\circle).nodes!.filter(r-tween-alive).length} of #{d3.select(p.root).select(\.pdmap-dorling).selectAll(\circle).size!} circles kept it"
    p.set-dorling-option transition: 0
    p.set values
    flush!

    p.set-dorling-option link: true
    flush!
    lines = node.select \.pdmap-links .selectAll \line
    ok 'one link line per circle', lines.size! == circles.size!, "#{lines.size!} lines"

    # auto radius: circles should together cover `fill-ratio` of the map box,
    # whatever the values happen to be.
    nr = (k) -> p.find-country(k)._node.r
    box-area = (p._bounds.1.0 - p._bounds.0.0) * (p._bounds.1.1 - p._bounds.0.1)
    covered = ->
      p._nodes.reduce ((a, n) -> a + Math.PI * n.r * n.r), 0
    p.set-dorling-option radius: {auto: true, fill-ratio: 0.4}
    ok 'auto radius covers the requested share of the map',
      Math.abs(covered! / box-area - 0.4) < 1e-6, "#{(covered! / box-area).toFixed 3} of the box"
    r-base = nr \tw
    p.set-dorling-option radius: {auto: true, fill-ratio: 0.1}
    ok 'halving the radius quarters the fill ratio',
      Math.abs(covered! / box-area - 0.1) < 1e-6
    ok 'lower fill-ratio shrinks every circle',
      Math.abs(nr(\tw) / r-base - 0.5) < 1e-6, "#{(nr(\tw) / r-base).toFixed 3} x"

    # with auto on, `max` is only an upper bound ...
    p.set-dorling-option radius: {auto: true, fill-ratio: 1, max: 3}
    ok 'radius.max caps the auto radius', nr(\tw) == 3, "tw:#{nr \tw}"
    # ... and with auto off it is taken literally
    p.set-dorling-option radius: {auto: false, max: 12}
    ok 'radius.max is used as-is when auto is off', nr(\tw) == 12, "tw:#{nr \tw}"
    p.set-dorling-option radius: {auto: true, fill-ratio: 0.4}
    flush!

    # bounds: nothing may sit outside the map box
    [[x0, y0], [x1, y1]] = p._bounds
    p._nodes.0.x = x0 - 1e4
    p._nodes.0.y = y1 + 1e4
    p.clamp-nodes!
    ok 'bounds pulls stray circles back inside',
      p._nodes.every -> x0 - 1e-6 <= it.x - it.r and it.x + it.r <= x1 + 1e-6 and
        y0 - 1e-6 <= it.y - it.r and it.y + it.r <= y1 + 1e-6

    # the force knobs have to land on the keys the library actually reads
    p.set-dorling-option strength: 0.42, collidePadding: 7
    ok 'strength / collidePadding reach the option set',
      p.dorling-opt.strength == 0.42 and p.dorling-opt.collide-padding == 7,
      "strength:#{p.dorling-opt.strength} collide:#{p.dorling-opt.collide-padding}"
    p.set-dorling-option strength: 0.15, collidePadding: 1.5

    p.set-dorling-option gravity: \center
    ok 'gravity:center aims every node at the map center',
      p._nodes.every(~> Math.abs(it.tx - p._center.0) < 1e-6)
    p.set-dorling-option gravity: \centroid
    ok 'gravity:centroid aims each node at its own centroid',
      p._nodes.every(-> Math.abs(it.tx - it.gx) < 1e-6)

    flush!
    ok 'dorling layer shown in dorling mode', opacity(p, \.pdmap-dorling) == 1
    ok 'choropleth layer hidden in dorling mode', opacity(p, \.pdmap-choropleth) == 0
    ok 'basemap shown when basemap:true', opacity(p, \.pdmap-basemap) == 1
    ok 'links shown when link:true', opacity(p, \.pdmap-links) == 1

    p.set-dorling-option basemap: false, link: false
    flush!
    ok 'basemap hidden when basemap:false', opacity(p, \.pdmap-basemap) == 0
    ok 'links hidden when link:false', opacity(p, \.pdmap-links) == 0

    ok 'unknown mode is a no-op', (p.mode(\nope) and p.mode!) == \dorling
    p.mode \choropleth, {animate: false}
    flush!
    ok 'mode() switches back to choropleth', p.mode! == \choropleth
    ok 'choropleth layer shown in choropleth mode', opacity(p, \.pdmap-choropleth) == 1
    ok 'dorling layer hidden in choropleth mode', opacity(p, \.pdmap-dorling) == 0

    # `mode` straight from the constructor, without ever calling mode()
    world.test2 = new pdmap-world do
      root: offscreen-svg \root-test2
      includes: <[china japan taiwan]>
      mode: \dorling
      tooltip: true
      dorling: {transition: 0}
    world.test2.init!
  .then ->
    p = world.test2
    p.fit!
    ok 'constructor {mode} needs no mode() call', p.mode! == \dorling, p.mode!
    ok 'includes narrows the country set', p.all-countries!length == 3,
      "#{p.all-countries!length} countries"
    p.set {cn: 9, jp: 4, tw: 1}
    flush!
    ok 'constructor dorling draws circles on the first set()',
      d3.select(p.root).select(\.pdmap-dorling).selectAll(\circle).size! == 3
    ok 'constructor dorling shows the dorling layer', opacity(p, \.pdmap-dorling) == 1
    ok 'constructor dorling hides the choropleth layer', opacity(p, \.pdmap-choropleth) == 0

    # ---- tooltip ----------------------------------------------------------
    circle = d3.select(p.root).select(\.pdmap-dorling).selectAll(\circle).nodes!0
    country = d3.select(circle).datum!
    hover = (el, x = 20, y = 20) ->
      el.dispatchEvent new MouseEvent \mousemove, {clientX: x, clientY: y, bubbles: true}

    ok 'countryOfDatum resolves a dorling circle datum', p.country-of-datum(country) == country
    ok 'countryOfDatum resolves a choropleth path datum',
      p.country-of-datum(p.wm.get country) == country
    ok 'countryOfDatum ignores anything else', p.country-of-datum({}) == null

    # targetRadius: the supported way to read what a circle is drawn at
    r-tw = p.target-radius \tw
    ok 'targetRadius takes an identifier', r-tw > 0, "#{(r-tw or 0).toFixed 1}"
    ok 'targetRadius matches the rendered r',
      Math.abs(r-tw - (radii p).tw) < 1e-9, "#{r-tw} vs #{(radii p).tw}"
    ok 'targetRadius takes a country object', p.target-radius(country) == p.target-radius(country.alpha2)
    ok 'targetRadius takes a choropleth datum',
      p.target-radius(p.wm.get country) == p.target-radius(country)
    ok 'targetRadius is null for a country with no value', p.target-radius(\fr) == null
    ok 'targetRadius is null for anything else', p.target-radius({}) == null

    hover circle
    tip = p.tip-node
    ok 'hovering a country shows the tooltip', !!(tip and tip.style.display == \block)
    ok 'tooltip names the country with its shortname',
      tip.querySelector('.pdmap-tip-name').textContent == country.shortname != country.name,
      tip.querySelector('.pdmap-tip-name').textContent
    ok 'tooltip shows the value',
      tip.querySelector('.pdmap-tip-value').textContent == "#{country.value}",
      tip.querySelector('.pdmap-tip-value').textContent

    p.set-tooltip-option format: (v) -> "#v units"
    hover circle
    ok 'tooltip.format is used',
      tip.querySelector('.pdmap-tip-value').textContent == "#{country.value} units"

    p.set-tooltip-option format: null, accessor: -> {name: \N, group: \G, value: \V, value-alt: \A}
    hover circle
    ok 'tooltip.accessor overrides the content',
      tip.querySelector('.pdmap-tip-name').textContent == \N and
        tip.querySelector('.pdmap-tip-group').textContent == \G
    ok 'tooltip renders valueAlt', tip.querySelector('.pdmap-tip-value-alt').textContent == \A

    p.set-tooltip-option accessor: -> null
    hover circle
    ok 'a null accessor hides the tooltip', tip.style.display == \none

    p.set-tooltip-option accessor: null
    hover circle
    p.root.dispatchEvent new MouseEvent \mouseleave
    ok 'leaving the map hides the tooltip', tip.style.display == \none

    hover circle
    p.set-tooltip-option enabled: false
    ok 'tooltip can be switched off', tip.style.display == \none
    hover circle
    ok 'a disabled tooltip stays hidden', tip.style.display == \none

    p.destroy!
    ok 'destroy() removes the tip node', !tip.parentNode and !p.tip-node

    render!
  .catch (e) ->
    ok 'tests ran without throwing', false, e.message
    render!
    console.error e
