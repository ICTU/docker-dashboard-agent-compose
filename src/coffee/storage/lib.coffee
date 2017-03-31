path          = require 'path'

module.exports =
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
