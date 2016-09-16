yaml  = require 'js-yaml'
fs    = require 'fs'
exec  = require('child_process').exec

module.exports = (config, publishState) ->


  start: (instance, composition) ->
    compose = yaml.safeDump composition
    scriptDir = "#{config.scriptBaseDir}/#{instance}"
    scriptPath = "#{scriptDir}/docker-compose.yml"

    fs.mkdir scriptDir, (err) ->
      unless not err or err.code is 'EEXIST'
        console.log 'Cannot make scriptDir', scriptDir, err
      else
        fs.writeFile scriptPath, compose, (err) ->
          if err then console.error 'ERR', err
          else
            exec "docker-compose -f #{scriptPath} -p #{instance} pull", (err, stdout, stderr) ->
              if err
                console.error 'ERR', err, stderr
              else
                console.log "docker-compose -f #{scriptPath} -p #{instance} pull", stdout
                exec "docker-compose -f #{scriptPath} -p #{instance} up -d", (err2, stdout2, stderr2) ->
                  if err2
                     console.error 'ERR', err, stderr2
                  else
                    console.log "docker-compose -f #{scriptPath} -p #{instance} up -d", stdout2



  stop: (instance) ->
    scriptDir = "#{config.scriptBaseDir}/#{instance}"
    scriptPath = "#{scriptDir}/docker-compose.yml"

    exec "docker-compose -f #{scriptPath} -p #{instance} down --remove-orphans", (err, stdout, stderr) ->
      if err then console.error 'ERR', err
      else
        console.log stdout, stderr
