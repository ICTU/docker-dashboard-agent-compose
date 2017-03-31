exec          = (require 'child_process').exec
fs            = require 'fs-extra'
path          = require 'path'
request       = require 'request'

lib           = require './storage/lib.coffee'

module.exports = (agent, mqtt, config) ->
  remoteFs = (cmd, payload, cb) ->
    request
      url: "#{config.remotefsUrl}/fs/#{cmd}"
      method: 'POST'
      json: payload
      , (err, res, body) ->
        console.error err if err
        cb err, body

  publishDataStoreUsage = (dir) -> ->
    exec "df -B1 #{dir} | tail -1 | awk '{ print $2 }{ print $3}{ print $5}'", (err, stdout, stderr) ->
      if err
        console.error err
        callback null, stderr
      totalSize = stdout.split("\n")[0]
      usedSize = stdout.split("\n")[1]
      percentage = stdout.split("\n")[2]
      mqtt.publish '/agent/storage/size',
        name: dir
        total: totalSize
        used: usedSize
        percentage: percentage

  setInterval publishDataStoreUsage(config.dataDir), 5000

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
      remoteFs 'rm', {dir: targetpath}, ->
        fs.unlink lockFile, callback

  agent.on '/storage/create', (params, {name, source}, callback) ->
    if source
      srcpath = path.join '/', config.domain, source
      targetpath = path.join '/', config.domain, name
      lockFile = path.join basePath, ".#{name}.copy.lock"
      fs.writeFile lockFile, "Copying #{srcpath} to #{targetpath}...", ->
        remoteFs 'cp', {source: srcpath, destination: targetpath}, ->
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
      remoteFs 'du', {dir: targetpath}, (err, response) ->
        fs.unlink lockFile, ->
          callback null, { name: name, size: response.size}
