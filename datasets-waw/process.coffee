fs = require 'fs'
stream = require 'stream'
JSONStream = require("JSONStream");

# Parsing invalid (not quoted fields) json and extracting foiarray field

parser = new stream.Transform({ objectMode: true } )

parser._buffer = ''
parser._instring = false
parser._level = 0 # object nested level
parser.__transform = (left) ->
  if !parser._instring
    # wrap field names in quotes to have valid JSON
    left = left.replace /([a-z_]\w*)\:/gi, "\"$1\":"

    # extract json objects from foiarray
    while (idx = left.search /\{|\}/) != -1
      if left[idx] == '{'
        parser._level++
        if parser._level == 2 # open feature
          parser._lastobj = '{'

      else
        parser._level--
        if parser._level == 1 # close feature
          parser._lastobj += left.substr 0, idx+1

          this.push parser._lastobj
          parser._lastobj = null

      left = left.substr idx+1

    if parser._level == 2
      parser._lastobj += left # add what's opened

  else if parser._level == 2 # add strings
    parser._lastobj += left

parser._transform = (chunk, encoding, done) ->
  data = parser._buffer + chunk.toString()

  while (idx = data.search /[^\\]"/) != -1
    idx++ # because of the preceeding char
    left = data.substr 0, idx+1
    right = data.substr idx+1

    this.__transform left
    data = right

    parser._instring = !parser._instring

  parser._buffer = data
  done()

parser._flush = (done) ->
  if parser._buffer
    this.__transform parser._buffer

  done()


## Transforming to GeoJson

tGeojson = new stream.Transform({ objectMode: true })
tGeojson._transform = (json, encoding, done) ->
  point = JSON.parse(json)

  props = {
    gtype: point.gtype,
  }
  for line in point.name.split "\n"
    fld = line.substr 0, (idx = line.indexOf ':')
    value = line.substr idx + 1
    props[fld.replace(/[^A-Z_0-9]/ig, '_').toLowerCase()] = value.substr 1

  this.push {
    type: 'Feature',
    id: point.id
    geometry:
      type: 'Point'
      coordinates: [point.x, point.y]
    properties: props
  }

  done()

tWrapInCollection = new stream.Transform({ objectMode: true })
tWrapInCollection._transform = (chunk, encoding, done) ->
  unless this._header_sent
    this.push '{"type": "FeatureCollection",
      "crs": {
        "type": "name",
        "properties": {
          "name": "urn:ogc:def:crs:EPSG:2178"
        }
      }, "features": '
    this._header_sent = true

  done null, chunk

tWrapInCollection._flush = (done) ->
  this.push '}'

  done()


## Evaluate

fs.createReadStream 'bike_shops_services.json'
 .pipe parser
 .pipe tGeojson
 .pipe JSONStream.stringify()
 .pipe tWrapInCollection
 .pipe process.stdout



# TODO pack similar like below but in coffee class
#util.inherits(SimpleProtocol, Transform);
#
#function SimpleProtocol(options) {
#  if (!(this instanceof SimpleProtocol))
#    return new SimpleProtocol(options);
#
#  Transform.call(this, options);
#this._inBody = false;
#this._sawFirstCr = false;
#this._rawHeader = [];
#this.header = null;
#}
#
#SimpleProtocol.prototype._transform = function(chunk, encoding, done) {


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
