exec          = (require 'child_process').exec
path          = require 'path'
request       = require 'request'

module.exports =
  runPeriodically: (f) -> setInterval f, 5000
  listStorageBuckets: (fs, dir, cb) ->
    fs.readdir dir, (err, dirList) ->
      if err
        console.error err
        cb? err, null
      else
        try
          files = dirList?.map (file) ->
            copyLock = ".#{file}.copy.lock"
            deleteLock = ".#{file}.delete.lock"
            stat = fs.statSync path.join(dir, file)
            if stat?.isDirectory()
              name: file
              created: stat.birthtime
              isLocked: copyLock in dirList or deleteLock in dirList
          .filter (file) -> file?
          cb? null, files
        catch ex
          cb? ex, null

  remoteFs: (remoteFsUrl, cmd, payload, cb) ->
    request
      url: "#{remoteFsUrl}/fs/#{cmd}"
      method: 'POST'
      json: payload
      , (err, res, body) ->
        console.error err if err
        cb err, body

  publishDataStoreUsage: (mqtt, dir) -> ->
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
