exec          = (require 'child_process').exec
fs            = require 'fs-extra'
path          = require 'path'

module.exports = (agent, mqtt, config) ->
  publishStorageBuckets = (err, buckets) ->
    mqtt.publish '/agent/storage/buckets', buckets unless err

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

  setInterval publishDataStoreUsage(basePath), 5000

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
        exec "cp -rp #{srcpath} #{targetpath}", ->
          fs.unlink lockFile, callback
    else
      fs.mkdirs targetpath, callback

  agent.on '/storage/size', ({name}, data, callback) ->
    targetpath = path.join basePath, name
    lockFile = path.join basePath, ".#{name}.size.lock"
    console.log "Retrieving size #{targetpath}"
    fs.writeFile lockFile, "Retrieving size #{targetpath} ...", ->
      exec "du -sb #{targetpath} | awk '{ print $1 }'", (err, stdout, stderr) ->
        if err
          console.error err
          fs.unlink lockFile, callback(null, stderr)
        bucketSize = stdout.replace(/^\s+|\s+$/g, '')
        fs.unlink lockFile, ->
          callback null, { name: name, size: bucketSize}
