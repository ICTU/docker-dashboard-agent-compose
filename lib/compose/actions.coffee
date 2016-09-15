yaml  = require 'js-yaml'
fs    = require 'fs'
exec  = require('child_process').exec

module.exports = (config, publishState) ->


  start: (instance, composition) ->
    compose = yaml.safeDump composition
    fs.writeFile "/tmp/temp", compose, (err) ->
      if err then console.error 'ERR', err
      else
        exec "docker-compose -f /tmp/temp -p #{instance} up -d", (err, stdout, stderr) ->
          if err then console.error 'ERR', err
          else
            console.log stdout, stderr



  stop: (instance) ->
    exec "docker-compose -f /tmp/temp -p #{instance} down", (err, stdout, stderr) ->
      if err then console.error 'ERR', err
      else
        console.log stdout, stderr
