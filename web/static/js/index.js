var $, flush, refitOnSettle, paint, randomData, world, maps, each, repaint, dorlingOpt, results, ok, render, offscreenSvg, rTweenAlive, opacity, radii, values;
$ = function(s){
  return document.querySelector(s);
};
flush = function(){
  if (d3.timerFlush) {
    return d3.timerFlush();
  }
};
refitOnSettle = function(p){
  if (p.sim) {
    return p.sim.on('end', function(){
      return p.fit();
    });
  }
};
paint = function(p, scale){
  var max, fill, node;
  scale == null && (scale = d3.interpolateYlGnBu);
  max = p.range()[1] || 1;
  fill = function(d){
    var c, v;
    c = pdmapWorld.countryOfDatum(d);
    v = c ? c.value : null;
    if (!(v != null) || v <= 0) {
      return '#eee';
    } else {
      return scale(v / max);
    }
  };
  node = d3.select(p.root);
  node.select('.pdmap-choropleth').selectAll('path').attr('fill', fill);
  node.select('.pdmap-dorling').selectAll('circle').attr('fill', fill);
  return p;
};
randomData = function(p){
  var data;
  data = {};
  p.allCountries().map(function(it){
    return data[it.num] = Math.round(Math.random() * 100);
  });
  return data;
};
world = {};
maps = [];
each = function(fn){
  return maps.map(function(m){
    return fn(m.p, m);
  });
};
repaint = function(){
  return maps.map(function(m){
    return paint(m.p, m.scale);
  });
};
dorlingOpt = function(){
  return {
    basemap: true,
    gravity: 'centroid',
    link: false,
    transition: 600,
    bounds: true
  };
};
Promise.resolve().then(function(){
  world.left = new pdmapWorld({
    root: '#root-left',
    tooltip: true,
    dorling: dorlingOpt()
  });
  return world.left.init();
}).then(function(){
  maps.push({
    p: world.left,
    scale: d3.interpolateYlGnBu
  });
  world.right = new pdmapWorld({
    root: '#root-right',
    includes: ['china', 'mongolia', 'taiwan', 'japan', 'kr', 'kp'],
    tooltip: true,
    dorling: dorlingOpt()
  });
  return world.right.init();
}).then(function(){
  var switchCtrl, rangeCtrl, applyRadius, i$, ref$, len$, id, results$ = [];
  maps.push({
    p: world.right,
    scale: d3.interpolateRainbow
  });
  each(function(p){
    p.set(randomData(p));
    p.fit();
    return refitOnSettle(p);
  });
  repaint();
  $('#mode-toggle').addEventListener('click', function(){
    var mode;
    mode = world.left.mode() === 'dorling' ? 'choropleth' : 'dorling';
    each(function(p){
      p.mode(mode);
      return refitOnSettle(p);
    });
    repaint();
    return this.textContent = "switch to " + (mode === 'dorling' ? 'choropleth' : 'dorling');
  });
  $('#reroll').addEventListener('click', function(){
    each(function(p){
      return p.set(randomData(p));
    });
    return repaint();
  });
  switchCtrl = function(id, key){
    return $("#" + id).addEventListener('change', function(){
      var v;
      v = this.type === 'checkbox'
        ? this.checked
        : this.value;
      return each(function(p){
        var o;
        o = {};
        o[key] = v;
        return p.setDorlingOption(o);
      });
    });
  };
  $('#opt-tooltip').addEventListener('change', function(){
    var this$ = this;
    return each(function(p){
      return p.setTooltipOption({
        enabled: this$.checked
      });
    });
  });
  switchCtrl('opt-basemap', 'basemap');
  switchCtrl('opt-link', 'link');
  switchCtrl('opt-bounds', 'bounds');
  switchCtrl('opt-gravity', 'gravity');
  rangeCtrl = function(id, key, fmt){
    var label;
    label = $("#" + id + "-value");
    return $("#" + id).addEventListener('input', function(){
      var v;
      v = parseFloat(this.value);
      label.textContent = fmt(v);
      each(function(p){
        var o;
        o = {};
        o[key] = v;
        return p.setDorlingOption(o);
      });
      return repaint();
    });
  };
  rangeCtrl('opt-strength', 'strength', function(v){
    return v.toFixed(2);
  });
  rangeCtrl('opt-collide', 'collidePadding', function(v){
    return v.toFixed(1);
  });
  applyRadius = function(){
    var max, fill;
    max = parseFloat($('#opt-radius').value);
    fill = parseFloat($('#opt-fill').value);
    $('#opt-radius-value').textContent = max > 0 ? max + "" : 'none';
    $('#opt-fill-value').textContent = fill.toFixed(2);
    each(function(p){
      return p.setDorlingOption({
        radius: {
          auto: $('#opt-auto').checked,
          fillRatio: fill,
          max: max > 0 ? max : void 8
        }
      });
    });
    return repaint();
  };
  for (i$ = 0, len$ = (ref$ = ['#opt-auto', '#opt-fill', '#opt-radius']).length; i$ < len$; ++i$) {
    id = ref$[i$];
    results$.push($(id).addEventListener(id === '#opt-auto' ? 'change' : 'input', applyRadius));
  }
  return results$;
});
results = [];
ok = function(name, pass, detail){
  detail == null && (detail = '');
  return results.push({
    name: name,
    pass: !!pass,
    detail: detail
  });
};
render = function(){
  var node, n, li;
  node = $('#tests');
  node.innerHTML = '';
  results.map(function(r){
    var li;
    li = document.createElement('li');
    li.className = r.pass ? 'text-success' : 'text-danger';
    li.textContent = (r.pass ? '✓' : '✗') + " " + r.name + (r.detail ? " ( " + r.detail + " )" : '');
    return node.appendChild(li);
  });
  n = results.filter(function(it){
    return it.pass;
  }).length;
  li = document.createElement('li');
  li.className = "mt-1 " + (n === results.length ? 'text-success' : 'text-danger');
  li.textContent = n + " / " + results.length + " passed";
  return node.appendChild(li);
};
offscreenSvg = function(id){
  var box;
  box = document.createElement('div');
  box.setAttribute('style', 'position:absolute;left:-9999px;top:0;width:480px;height:320px;');
  box.innerHTML = "<svg id=\"" + id + "\" style=\"width:100%;height:100%\"></svg>";
  document.body.appendChild(box);
  return box.firstChild;
};
rTweenAlive = function(el){
  var t;
  if (!(t = el.__transition)) {
    return false;
  }
  return Object.keys(t).filter(function(it){
    return it !== 'active';
  }).some(function(k){
    return t[k].tween.some(function(x){
      return x.name === 'attr.r';
    });
  });
};
opacity = function(p, cls){
  return parseFloat(d3.select(p.root).select(cls).style('opacity'));
};
radii = function(p){
  var o;
  o = {};
  d3.select(p.root).select('.pdmap-dorling').selectAll('circle').each(function(d){
    return o[d.alpha2] = parseFloat(this.getAttribute('r'));
  });
  return o;
};
values = {
  tw: 100,
  jp: 64,
  us: 25,
  de: 4
};
Promise.resolve().then(function(){
  world.test = new pdmapWorld({
    root: offscreenSvg('root-test'),
    dorling: {
      transition: 0
    }
  });
  return world.test.init();
}).then(function(){
  var p, node, i$, ref$, len$, cls, circles, datum, rs, r2, lines, nr, boxArea, covered, rBase, ref1$, x0, y0, x1, y1;
  p = world.test;
  p.fit();
  node = d3.select(p.root);
  ok('mode() defaults to choropleth', p.mode() === 'choropleth', p.mode());
  ok('tooltip is off unless asked for', p.tooltipOpt.enabled === false);
  for (i$ = 0, len$ = (ref$ = ['.pdmap-basemap', '.pdmap-choropleth', '.pdmap-links', '.pdmap-dorling']).length; i$ < len$; ++i$) {
    cls = ref$[i$];
    ok("layer " + cls + " exists", !node.select(cls).empty());
  }
  p.set(values);
  p.mode('dorling', {
    animate: false
  });
  paint(p);
  flush();
  ok('mode() switches to dorling', p.mode() === 'dorling');
  circles = node.select('.pdmap-dorling').selectAll('circle');
  ok('one circle per valued country', circles.size() === Object.keys(values).length, circles.size() + " circles");
  datum = circles.size() ? d3.select(circles.nodes()[0]).datum() : null;
  ok('circle datum is the country object', !!(datum && datum.num != null && datum.value != null));
  rs = radii(p);
  ok('radius grows with value', rs.tw > (ref$ = rs.jp) && ref$ > (ref$ = rs.us) && ref$ > rs.de, ['tw', 'jp', 'us', 'de'].map(function(it){
    return it + ":" + (rs[it] || 0).toFixed(1);
  }).join(' '));
  ok('radius follows a sqrt scale', Math.abs(rs.tw / rs.us - 2) < 0.01, "tw/us = " + (rs.tw / rs.us).toFixed(3));
  p.set({
    tw: values.de
  });
  flush();
  r2 = radii(p).tw;
  ok('set() updates radii in place', 0 < r2 && r2 < rs.tw, r2.toFixed(1) + " < " + rs.tw.toFixed(1));
  p.set(values);
  flush();
  p.setDorlingOption({
    transition: 300
  });
  p.set({
    tw: values.de,
    de: values.tw
  });
  d3.select(p.root).selectAll('circle').transition().duration(350).attr('fill', '#123456');
  flush();
  ok('a host transition on the circles does not cancel the radius update', d3.select(p.root).select('.pdmap-dorling').selectAll('circle').nodes().every(rTweenAlive), d3.select(p.root).select('.pdmap-dorling').selectAll('circle').nodes().filter(rTweenAlive).length + " of " + d3.select(p.root).select('.pdmap-dorling').selectAll('circle').size() + " circles kept it");
  p.setDorlingOption({
    transition: 0
  });
  p.set(values);
  flush();
  p.setDorlingOption({
    link: true
  });
  flush();
  lines = node.select('.pdmap-links').selectAll('line');
  ok('one link line per circle', lines.size() === circles.size(), lines.size() + " lines");
  nr = function(k){
    return p.findCountry(k)._node.r;
  };
  boxArea = (p._bounds[1][0] - p._bounds[0][0]) * (p._bounds[1][1] - p._bounds[0][1]);
  covered = function(){
    return p._nodes.reduce(function(a, n){
      return a + Math.PI * n.r * n.r;
    }, 0);
  };
  p.setDorlingOption({
    radius: {
      auto: true,
      fillRatio: 0.4
    }
  });
  ok('auto radius covers the requested share of the map', Math.abs(covered() / boxArea - 0.4) < 1e-6, (covered() / boxArea).toFixed(3) + " of the box");
  rBase = nr('tw');
  p.setDorlingOption({
    radius: {
      auto: true,
      fillRatio: 0.1
    }
  });
  ok('halving the radius quarters the fill ratio', Math.abs(covered() / boxArea - 0.1) < 1e-6);
  ok('lower fill-ratio shrinks every circle', Math.abs(nr('tw') / rBase - 0.5) < 1e-6, (nr('tw') / rBase).toFixed(3) + " x");
  p.setDorlingOption({
    radius: {
      auto: true,
      fillRatio: 1,
      max: 3
    }
  });
  ok('radius.max caps the auto radius', nr('tw') === 3, "tw:" + nr('tw'));
  p.setDorlingOption({
    radius: {
      auto: false,
      max: 12
    }
  });
  ok('radius.max is used as-is when auto is off', nr('tw') === 12, "tw:" + nr('tw'));
  p.setDorlingOption({
    radius: {
      auto: true,
      fillRatio: 0.4
    }
  });
  flush();
  ref$ = p._bounds, ref1$ = ref$[0], x0 = ref1$[0], y0 = ref1$[1], ref1$ = ref$[1], x1 = ref1$[0], y1 = ref1$[1];
  p._nodes[0].x = x0 - 1e4;
  p._nodes[0].y = y1 + 1e4;
  p.clampNodes();
  ok('bounds pulls stray circles back inside', p._nodes.every(function(it){
    return x0 - 1e-6 <= it.x - it.r && it.x + it.r <= x1 + 1e-6 && y0 - 1e-6 <= it.y - it.r && it.y + it.r <= y1 + 1e-6;
  }));
  p.setDorlingOption({
    strength: 0.42,
    collidePadding: 7
  });
  ok('strength / collidePadding reach the option set', p.dorlingOpt.strength === 0.42 && p.dorlingOpt.collidePadding === 7, "strength:" + p.dorlingOpt.strength + " collide:" + p.dorlingOpt.collidePadding);
  p.setDorlingOption({
    strength: 0.15,
    collidePadding: 1.5
  });
  p.setDorlingOption({
    gravity: 'center'
  });
  ok('gravity:center aims every node at the map center', p._nodes.every(function(it){
    return Math.abs(it.tx - p._center[0]) < 1e-6;
  }));
  p.setDorlingOption({
    gravity: 'centroid'
  });
  ok('gravity:centroid aims each node at its own centroid', p._nodes.every(function(it){
    return Math.abs(it.tx - it.gx) < 1e-6;
  }));
  flush();
  ok('dorling layer shown in dorling mode', opacity(p, '.pdmap-dorling') === 1);
  ok('choropleth layer hidden in dorling mode', opacity(p, '.pdmap-choropleth') === 0);
  ok('basemap shown when basemap:true', opacity(p, '.pdmap-basemap') === 1);
  ok('links shown when link:true', opacity(p, '.pdmap-links') === 1);
  p.setDorlingOption({
    basemap: false,
    link: false
  });
  flush();
  ok('basemap hidden when basemap:false', opacity(p, '.pdmap-basemap') === 0);
  ok('links hidden when link:false', opacity(p, '.pdmap-links') === 0);
  ok('unknown mode is a no-op', (p.mode('nope') && p.mode()) === 'dorling');
  p.mode('choropleth', {
    animate: false
  });
  flush();
  ok('mode() switches back to choropleth', p.mode() === 'choropleth');
  ok('choropleth layer shown in choropleth mode', opacity(p, '.pdmap-choropleth') === 1);
  ok('dorling layer hidden in choropleth mode', opacity(p, '.pdmap-dorling') === 0);
  world.test2 = new pdmapWorld({
    root: offscreenSvg('root-test2'),
    includes: ['china', 'japan', 'taiwan'],
    mode: 'dorling',
    tooltip: true,
    dorling: {
      transition: 0
    }
  });
  return world.test2.init();
}).then(function(){
  var p, circle, country, hover, rTw, tip, ref$;
  p = world.test2;
  p.fit();
  ok('constructor {mode} needs no mode() call', p.mode() === 'dorling', p.mode());
  ok('includes narrows the country set', p.allCountries().length === 3, p.allCountries().length + " countries");
  p.set({
    cn: 9,
    jp: 4,
    tw: 1
  });
  flush();
  ok('constructor dorling draws circles on the first set()', d3.select(p.root).select('.pdmap-dorling').selectAll('circle').size() === 3);
  ok('constructor dorling shows the dorling layer', opacity(p, '.pdmap-dorling') === 1);
  ok('constructor dorling hides the choropleth layer', opacity(p, '.pdmap-choropleth') === 0);
  circle = d3.select(p.root).select('.pdmap-dorling').selectAll('circle').nodes()[0];
  country = d3.select(circle).datum();
  hover = function(el, x, y){
    x == null && (x = 20);
    y == null && (y = 20);
    return el.dispatchEvent(new MouseEvent('mousemove', {
      clientX: x,
      clientY: y,
      bubbles: true
    }));
  };
  ok('countryOfDatum resolves a dorling circle datum', p.countryOfDatum(country) === country);
  ok('countryOfDatum resolves a choropleth path datum', p.countryOfDatum(p.wm.get(country)) === country);
  ok('countryOfDatum ignores anything else', p.countryOfDatum({}) === null);
  rTw = p.targetRadius('tw');
  ok('targetRadius takes an identifier', rTw > 0, (rTw || 0).toFixed(1) + "");
  ok('targetRadius matches the rendered r', Math.abs(rTw - radii(p).tw) < 1e-9, rTw + " vs " + radii(p).tw);
  ok('targetRadius takes a country object', p.targetRadius(country) === p.targetRadius(country.alpha2));
  ok('targetRadius takes a choropleth datum', p.targetRadius(p.wm.get(country)) === p.targetRadius(country));
  ok('targetRadius is null for a country with no value', p.targetRadius('fr') === null);
  ok('targetRadius is null for anything else', p.targetRadius({}) === null);
  hover(circle);
  tip = p.tipNode;
  ok('hovering a country shows the tooltip', !!(tip && tip.style.display === 'block'));
  ok('tooltip names the country with its shortname', tip.querySelector('.pdmap-tip-name').textContent === (ref$ = country.shortname) && ref$ !== country.name, tip.querySelector('.pdmap-tip-name').textContent);
  ok('tooltip shows the value', tip.querySelector('.pdmap-tip-value').textContent === country.value + "", tip.querySelector('.pdmap-tip-value').textContent);
  p.setTooltipOption({
    format: function(v){
      return v + " units";
    }
  });
  hover(circle);
  ok('tooltip.format is used', tip.querySelector('.pdmap-tip-value').textContent === country.value + " units");
  p.setTooltipOption({
    format: null,
    accessor: function(){
      return {
        name: 'N',
        group: 'G',
        value: 'V',
        valueAlt: 'A'
      };
    }
  });
  hover(circle);
  ok('tooltip.accessor overrides the content', tip.querySelector('.pdmap-tip-name').textContent === 'N' && tip.querySelector('.pdmap-tip-group').textContent === 'G');
  ok('tooltip renders valueAlt', tip.querySelector('.pdmap-tip-value-alt').textContent === 'A');
  p.setTooltipOption({
    accessor: function(){
      return null;
    }
  });
  hover(circle);
  ok('a null accessor hides the tooltip', tip.style.display === 'none');
  p.setTooltipOption({
    accessor: null
  });
  hover(circle);
  p.root.dispatchEvent(new MouseEvent('mouseleave'));
  ok('leaving the map hides the tooltip', tip.style.display === 'none');
  hover(circle);
  p.setTooltipOption({
    enabled: false
  });
  ok('tooltip can be switched off', tip.style.display === 'none');
  hover(circle);
  ok('a disabled tooltip stays hidden', tip.style.display === 'none');
  p.destroy();
  ok('destroy() removes the tip node', !tip.parentNode) && !p.tipNode;
  return render();
})['catch'](function(e){
  ok('tests ran without throwing', false, e.message);
  render();
  return console.error(e);
});