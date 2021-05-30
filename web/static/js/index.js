var world;
world = {};
Promise.resolve().then(function(){
  world.left = new pdmapWorld({
    root: '#root-left'
  });
  return world.left.init();
}).then(function(){
  var p, data, scale;
  p = world.left;
  data = {};
  p.allCountries().map(function(it){
    return data[it.name] = Math.random();
  });
  p.set(data);
  scale = d3.interpolateYlOrRd;
  p.fit();
  return d3.select(p.root).selectAll('path').attr('fill', function(d, i){
    var v;
    v = d.properties.value || 0;
    if (v <= 0) {
      return '#eee';
    }
    return scale((d.properties.value || 0) / p.range()[1]);
  });
}).then(function(){
  world.right = new pdmapWorld({
    root: '#root-right',
    includes: ['china', 'mongolia', 'taiwan', 'japan', 'kr', 'kp']
  });
  return world.right.init();
}).then(function(){
  var p, data, scale;
  p = world.right;
  data = {};
  p.allCountries().map(function(it){
    return data[it.name] = Math.random();
  });
  p.set(data);
  scale = d3.interpolateRainbow;
  p.fit();
  return d3.select(p.root).selectAll('path').attr('fill', function(d, i){
    var v;
    v = d.properties.value || 0;
    if (v <= 0) {
      return '#eee';
    }
    return scale((d.properties.value || 0) / p.range()[1]);
  });
});