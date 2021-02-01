/*
(->
  ne = d3.geoNaturalEarth1Raw
  pdmap-world = do
    projection: d3.geoProjection (x,y) ->
      lat = y * 180 / Math.PI
      lng = x * 180 / Math.PI
      if lng < -160 and lat < 40 => lng += 20
      else if lng < -140 and lat < 40 => lng += 10
      x = lng * Math.PI / 180
      y = lat * Math.PI / 180
      return ne x, y

    create: (opt = {}) -> new inst opt
    meta: {}
    nametypes: <[name alpha2 alpha3 gapminder num shortname]>
    countries: []
    find-country: (n) ->
      if @meta.zhalpha2[n] => n = that
      if typeof(n) == \string => n = n.toLowerCase!
      for item in @countries => for key in @nametypes =>
        if item[key] == n => return item

      return null

  inst = (opt = {}) ->
    @root = if typeof(opt.root) == typeof('') => document.querySelector(opt.root) else opt.root
    @ <<< {lc: {}, excludes: opt.excludes or []}
    @ <<< opt{type, popup, baseurl, padding}
    @

  inst.prototype = Object.create(Object.prototype) <<< do
    init: ->
      {root, type, popup} = @{root, type, popup}
      root.addEventListener \mousemove, (e) ->
        if !(n = e.target) => return
        if n.nodeType != 1 => return
        if !(data = d3.select(n).datum!) => return
        if popup? => popup {evt: e, data}
      ld$.fetch (@baseurl or "") + "/topo.json", {method: \GET}, {type: \json}
        .then (topo) ~>
          @lc.topo = topo
          ld$.fetch (@baseurl or "") + "/count.json", {method: \GET}, {type: \json}
        .then (count) ~>
          @lc.count = count
          ld$.fetch (@baseurl or "") + "/meta.json", {method: \GET}, {type: \json}
        .then (meta) ~>
          @lc.meta = meta
          pdmap-world.meta = meta
          @lc.wm = new WeakMap!
          features = topojson.feature(@lc.topo, @lc.topo.objects["countries"]).features
          features.map (f) ~>
             idx = meta.num.indexOf(f.id)
             f.properties = obj = {}
             @lc.wm.set obj, f
             pdmap-world.nametypes.map (n) -> obj[n] = meta[n][idx]
             pdmap-world.countries.push obj
          @excludes = @excludes
            .map -> if ret = pdmap-world.find-country(it) => ret.num else null
            .filter -> it
          @lc.features = features = features.filter ~> !(it.properties.num in @excludes)
          max = 0
          for k,v of @lc.count =>
            ret = pdmap-world.find-country k
            if ret => ret.value = v
            if v > max => max = v
          @lc.max = max
          @lc.path = path = d3.geoPath!.projection pdmap-world.projection
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
      g = ld$.find root, \g, 0
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

  if window? => window.pdmap-world = pdmap-world
  if module? => module.exports = pdmap-world

  p = pdmap-world.create root: '#root', baseurl: '/assets/data', excludes: [10]
  p.init!then ->
    scale = d3.interpolateYlOrRd
    p.fit!
    d3.select \svg .selectAll \path
      .attr \fill, (d,i) ~>
        v = d.properties.value or 0
        if v <= 0 => return \#eee
        scale (d.properties.value or 0) / p.lc.max
)!
*/
