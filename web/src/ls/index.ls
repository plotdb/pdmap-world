world = {}

Promise.resolve!
  .then ->
    world.left = new pdmap-world root: '#root-left'
    world.left.init!
  .then ->
    p = world.left
    data = {}
    p.all-countries!map -> data[it.name] = Math.random!
    p.set data
    scale = d3.interpolateYlOrRd
    p.fit!
    d3.select p.root .selectAll \path
      .attr \fill, (d,i) ~>
        v = d.properties.value or 0
        if v <= 0 => return \#eee
        scale (d.properties.value or 0) / p.range!1
  .then ->
    world.right = new pdmap-world root: '#root-right', includes: <[china mongolia taiwan japan kr kp]>
    world.right.init!
  .then ->
    p = world.right
    data = {}
    p.all-countries!map -> data[it.name] = Math.random!
    p.set data
    scale = d3.interpolateRainbow
    p.fit!
    d3.select p.root .selectAll \path
      .attr \fill, (d,i) ~>
        v = d.properties.value or 0
        if v <= 0 => return \#eee
        scale (d.properties.value or 0) / p.range!1
