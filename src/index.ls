meta = require "./meta.json"
topo = require "./topo.json"

ne = d3.geoNaturalEarth1Raw

pdmap-world = (opt = {}) ->
  @root = if typeof(opt.root) == typeof('') => document.querySelector(opt.root) else opt.root
  @ <<< {excludes: opt.excludes or [], includes: opt.includes or []}
  @ <<< {features: [], path: null, wm: new WeakMap!, countries: []}
  @ <<< opt{popup, padding}
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
        root.addEventListener \mousemove, (e) ->
          if !(n = e.target) => return
          if n.nodeType != 1 => return
          if !(data = d3.select(n).datum!) => return
          if popup? => popup {evt: e, data}
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
        node = if root.nodeName.toLowerCase! == \svg => d3.select(root) else d3.select(root).append(\svg)
        node.append(\g)
          .attr \class, \pdmap-world
          .selectAll \path
          .data features
          .enter!
            .append \path
            .attr \d, path

  fit: ->
    root = @root
    g = root.querySelector(\g)
    if root.nodeName.toLowerCase! != \svg =>
      svg = d3.select(root).select(\svg)
      svg.attr \width, \100%
      svg.attr \height, \100%
    bcr = root.getBoundingClientRect!
    bbox = g.getBBox!
    [width,height] = [bcr.width,bcr.height]
    padding = if @padding? => @padding else 20
    scale = Math.min((width - 2 * padding) / bbox.width, (height - 2 * padding) / bbox.height)
    [w,h] = [width / 2, height / 2]
    g.setAttribute(
      \transform
      "translate(#w,#h) scale(#scale) translate(#{-bbox.x - bbox.width/2},#{-bbox.y - bbox.height/2})"
    )

  set: (o = {}) ->
    for k,v of o =>
      country = @find-country k
      if !country => continue
      country.value = v

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

if window? => window.pdmap-world = pdmap-world
if module? => module.exports = pdmap-world
