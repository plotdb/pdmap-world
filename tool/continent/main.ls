require! <[fs]>

zh = 
  'Asia': "亞洲"
  'Europe': "歐洲"
  'Antarctica': "南極洲"
  'Africa': "非洲"
  'Oceania': "大洋洲"
  'North America': "北美洲"
  'South America': "南美洲"

code = JSON.parse(fs.read-file-sync 'source.json' .toString!)
list = Array.from(new Set(code.map -> it.Continent_Name))
meta = JSON.parse(fs.read-file-sync '../../src/meta.json' .toString!)
codemap = Object.fromEntries(code.map -> [it.Two_Letter_Country_Code.toLowerCase!, list.indexOf(it.Continent_Name)])
map = meta.alpha2.map(-> codemap[it])
names = list
continent = {map, names, zh: names.map -> zh[it]}

fs.write-file-sync 'continent.json', JSON.stringify(continent)
