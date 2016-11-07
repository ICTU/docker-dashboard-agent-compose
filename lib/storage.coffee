fs            = require 'fs-extra'
path          = require 'path'

module.exports = (agent, mqtt, config) ->
  publishStorageBuckets = (err, buckets) ->
    mqtt.publish '/agent/storage/buckets', buckets unless err

  listStorageBuckets = (dir, cb) ->
    fs.readdir dir, (err, dirList) ->
      if err
        console.error err
        cb? err, null
      else
        try
          files = dirList?.map (file) ->
            copyLock = ".#{file}.copy.lock"
            deleteLock = ".#{file}.delete.lock"
            stat = fs.statSync path.join(basePath, file)
            if stat.isDirectory()
              name: file
              created: stat.birthtime
              isLocked: copyLock in dirList or deleteLock in dirList
          .filter (file) -> file?
          cb? null, files
        catch ex
          cb? ex, null

  basePath = path.join config.dataDir, config.domain

  listStorageBuckets basePath, publishStorageBuckets
  fs.watch basePath, (eventType, filename) ->
    listStorageBuckets basePath, publishStorageBuckets

  agent.on '/storage/list', (params, data, callback) ->
    listStorageBuckets basePath, (err, buckets) ->
      publishStorageBuckets err, buckets
      callback()

  agent.on '/storage/delete', ({name}, data, callback) ->
    srcpath = path.join basePath, name
    lockFile = path.join basePath, ".#{name}.delete.lock"
    fs.writeFile lockFile, "Deleting #{srcpath}...", ->
      fs.remove srcpath, ->
        fs.unlink lockFile, callback

  agent.on '/storage/create', (params, {name, source}, callback) ->
    targetpath = path.join basePath, name
    if source
      srcpath = path.join basePath, source
      lockFile = path.join basePath, ".#{name}.copy.lock"
      fs.writeFile lockFile, "Copying #{srcpath} to #{targetpath}...", ->
        child_process.exec "cp -rp #{srcpath} #{targetpath}", ->
          fs.unlink lockFile, callback
    else
      fs.mkdirs targetpath, callback
