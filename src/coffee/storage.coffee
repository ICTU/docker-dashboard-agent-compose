fs            = require 'fs-extra'
path          = require 'path'
lib           = require './storage/lib.coffee'

module.exports = (agent, mqtt, config) ->

  setInterval lib.publishDataStoreUsage(mqtt, config.dataDir), 5000

  publishStorageBuckets = (err, buckets) ->
    mqtt.publish '/agent/storage/buckets', buckets unless err


  basePath = path.join config.dataDir, config.domain

  lib.listStorageBuckets fs, basePath, publishStorageBuckets
  fs.watch basePath, (eventType, filename) ->
    lib.listStorageBuckets fs, basePath, publishStorageBuckets

  agent.on '/storage/list', (params, data, callback) ->
    lib.listStorageBuckets fs, basePath, (err, buckets) ->
      publishStorageBuckets err, buckets
      callback()

  agent.on '/storage/delete', ({name}, data, callback) ->
    targetpath = path.join '/', config.domain, name
    lockFile = path.join basePath, ".#{name}.delete.lock"
    fs.writeFile lockFile, "Deleting #{targetpath}...", ->
      lib.remoteFs config.remotefsUrl, 'rm', {dir: targetpath}, ->
        fs.unlink lockFile, callback

  agent.on '/storage/create', (params, {name, source}, callback) ->
    if source
      srcpath = path.join '/', config.domain, source
      targetpath = path.join '/', config.domain, name
      lockFile = path.join basePath, ".#{name}.copy.lock"
      fs.writeFile lockFile, "Copying #{srcpath} to #{targetpath}...", ->
        lib.remoteFs config.remotefsUrl, 'cp', {source: srcpath, destination: targetpath}, ->
          fs.unlink lockFile, callback
    else
      targetpath = path.join basePath, name
      console.log "Creating bucket #{targetpath}"
      fs.mkdirs targetpath, callback

  agent.on '/storage/size', ({name}, data, callback) ->
    targetpath = path.join '/', config.domain, name
    lockFile = path.join basePath, ".#{name}.size.lock"
    console.log "Retrieving size #{targetpath}"
    fs.writeFile lockFile, "Retrieving size #{targetpath} ...", ->
      lib.remoteFs config.remotefsUrl, 'du', {dir: targetpath}, (err, response) ->
        fs.unlink lockFile, ->
          callback null, { name: name, size: response.size}
