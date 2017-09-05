fs    = require 'fs-extra'
path  = require 'path'
chokidar = require 'chokidar'

lib   = require './storage/lib.coffee'

module.exports = (agent, mqtt, config) ->

  publishStorageBuckets = (err, buckets) ->
    mqtt.publish '/agent/storage/buckets', buckets unless err

  basePath = path.join config.dataDir, config.domain

  if config.datastore?.scanEnabled
    lib.runPeriodically lib.publishDataStoreUsage(mqtt, '/agent/storage/size', config.dataDir)
    lib.runPeriodically lib.publishDataStoreUsage(mqtt, '/agent/docker/graph', config.docker.graph.path)

    listBucketsCb = (fileName, fileStats) ->
      console.log "#{fileName} changed. Listing storage buckets..."
      lib.listStorageBuckets fs, basePath, publishStorageBuckets

    listBucketsCb()
    opts =
      usePolling: true
      ignored: path.join basePath, '/*/**'

    ['addDir', 'unlinkDir'].map (e) -> chokidar.watch(basePath, opts).on e, listBucketsCb
    chokidar.watch(path.join(basePath, '/.*'), opts).on 'unlink', listBucketsCb

  agent.on '/storage/list', (params, data, callback) ->
    lib.listStorageBuckets fs, basePath, (err, buckets) ->
      publishStorageBuckets err, buckets
      callback()

  agent.on '/storage/delete', ({name}, data, callback) ->
    targetpath = path.join '/', config.domain, name
    lockFile = path.join basePath, ".#{name}.delete.lock"
    fs.writeFile lockFile, "Deleting #{targetpath}...", ->
      console.log "Deleting #{targetpath}..."
      lib.remoteFs config.remotefsUrl, 'rm', {dir: targetpath}, (err) ->
        unless err
          console.log "#{targetpath} was successfully deleted"
          fs.unlink lockFile, callback
        else
          callback err

  agent.on '/storage/create', (params, {name, source}, callback) ->
    if source
      srcpath = path.join '/', config.domain, source
      targetpath = path.join '/', config.domain, name
      lockFile = path.join basePath, ".#{name}.copy.lock"
      fs.writeFile lockFile, "Copying #{srcpath} to #{targetpath}...", ->
        console.log "Copying #{srcpath} to #{targetpath}..."
        lib.remoteFs config.remotefsUrl, 'cp', {source: srcpath, destination: targetpath}, (err) ->
          unless err
            console.log "#{srcpath} was successfully copied to #{targetpath}"
            fs.unlink lockFile, callback
          else
            callback err
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
        unless err
          fs.unlink lockFile, ->
            callback null, { name: name, size: response.size}
        else
          callback err
