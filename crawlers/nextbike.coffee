xmlnodes = require 'xml-nodes'
xmlobjects = require 'xml-objects'
request = require 'request'
StringStream = require 'string-stream'

NEXTBIKE_API_KEY = 'b6a747d0699411e498030800200c9a66' # 32 chars

module.exports = (agenda) ->
  process = (job, done) ->
    status = {}
    all_processed = false
    queued = 0
    check_if_done = ->
      proc = 0
      err = 0
      ok = 0
      for alias of status
        proc++ if status[alias] == 'processing'
        err++ if status[alias] == 'err'
        ok++ if status[alias] == 'ok'
      console.log 'P' + all_processed + ' ' + proc + '-' + err + '-' + ok

      if all_processed and err + ok == queued
        console.log 'Processed!'
        done()
        return true
      false


    # fs.createReadStream(__dirname + '/../test/public-bikes-nextbike-feed-20141108T1727.xml') for testing with no-internet
    request 'https://nextbike.net/maps/nextbike-live.xml'
    .pipe xmlnodes 'country'
      .pipe xmlobjects {explicitRoot: false, explicitArray: false, mergeAttrs: true}
        .on 'data', (country) ->
          country.city = [country.city] if not Array.isArray country.city

          # network per city
          for city in country.city
            do (city) ->
              alias = 'nextbike-' + city.uid
              console.log 'Processing ' + alias + '[' + country.name + ' - ' + city.name + ']'

              network = {
                name: country.name,
                alias: alias,
                countryCode: country.country.toLowerCase(),
              # hotline: country.hotline,
                cityName: city.name,
                cityLatitude: parseFloat(city.lat),
                cityLongitude: parseFloat(city.lng),
              }

              status[alias] = 'processing'
              queued++

              network.stations = {
                type: "FeatureCollection",
                features: for place in city.place
                  {
                    type: 'Feature',
                    geometry: {
                      type: 'Point',
                      coordinates: [parseFloat(place.lng), parseFloat(place.lat)]
                    },
                    properties: {
                        uniqueId: place.uid,
                        stationId: place.number,
                        stationName: place.name,
                        totalDocks: parseInt(place.bike_racks),
                      #canParkIfNoDocksAvailable: true
                    }
                  }
              }
              snetwork = JSON.stringify(network)

              # Push data using API
              s = new StringStream(snetwork)

              s.pipe (request.post {
                uri: 'http://localhost:3000/public_bikes?api_key=' + NEXTBIKE_API_KEY
                headers: {
                  'Content-Type': 'application/json'
                }}, (error, resp, body) ->
                  if error || !resp || resp.statusCode < 200 || resp.statusCode > 300
                    status[network.alias] = 'err' # statusCode
                    console.log 'ERR on ' + alias + ' ' + network.name + ' ' + network.cityName
                    if body
                      console.log body
                    else
                      console.log error.code #ie. ECONNREFUSED

                  else
                    status[network.alias] = 'ok'

                  check_if_done()
              )

            # TODO stream cities instead of in-memory?
            #  .pipe(JSONStream.stringify())

            null# on 'data' result

        .on 'end', ->
            console.log 'DONE'
            all_processed = true
            check_if_done()

  process null, ->

#  agenda.define 'nextbike-global-stations', {concurrency: 1}, (job, done) ->
#    console.log('TICK nextbike-global-stations ' + Date.now())
#    done()
#
#  agenda.every '5 seconds', 'nextbike-global-stations'