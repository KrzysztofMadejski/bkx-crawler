fs = require 'fs'
stream = require 'stream'
djson = require('dirty-json')
parser = new stream.Transform() #( { objectMode: true } )

parser._buffer = ''
parser._instring = false
parser._transform = (chunk, encoding, done) ->
  data = parser._buffer + chunk.toString()

  while (idx = data.search /[^\\]"/) != -1
    idx++ # because of the preceeding char
    left = data.substr 0, idx + 1
    right = data.substr idx + 1

    if !parser._instring
      left = left.replace /([a-z_]\w*)\:/gi, "\"$1\":"

    this.push left
    data = right
    parser._instring = !parser._instring

  parser._buffer = data

  done()

#liner._flush = function (done) {
#  if (this._lastLineData) this.push(this._lastLineData)
#  this._lastLineData = null
#  done()
#}

fs.createReadStream 'bike_shops_services.json'
 .pipe parser
 .pipe process.stdout

#fs.readFile 'bike_shops_services.json', (err, data) ->
#  if err
#    throw err
#
#  djson.parse(data.toString()).then (obj) ->
#    features = for point in obj.foiarray
#      meta = {
#        gtype: point.gtype,
#      }
#      for line in point.name.split "\\n"
#        [fld, value] = line.split ':', 2
#        meta[fld.replace(/[^A-Z_0-9]/ig, '_').toLowerCase()] = value.substr 1
#
#      {
#        type: 'Feature',
#        id: point.id
#        geometry:
#          type: 'Point'
#          coordinates: [point.x, point.y]
#        properties: meta
#      }
#
#    console.log JSON.stringify {
#      type: 'FeatureCollection',
#      features: features,
#      crs:
#        type: "name",
#        properties: {
#          "name": "urn:ogc:def:crs:EPSG:2178"
#        }
#    }
#
