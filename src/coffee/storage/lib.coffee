exec          = (require 'child_process').exec
path          = require 'path'

module.exports =
  runPeriodically: (f) -> setInterval f, 5000

  remoteFs: (mqtt) -> (op, msg) ->
    mqtt.publish "/commands/remotefs/#{op}", msg, {retain: false, qos: 2}

  publishDataStoreUsage: (mqtt, topic, dir) -> ->
    exec "df -B1 #{dir} | tail -1 | awk '{ print $2 }{ print $3}{ print $5}'", (err, stdout, stderr) ->
      if err
        console.error err
        callback null, stderr
      totalSize = stdout.split("\n")[0]
      usedSize = stdout.split("\n")[1]
      percentage = stdout.split("\n")[2]
      mqtt.publish topic,
        name: dir
        total: totalSize
        used: usedSize
        percentage: percentage
