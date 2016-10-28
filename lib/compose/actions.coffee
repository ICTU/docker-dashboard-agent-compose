events = require 'events'
exec   = require('child_process').exec
spawn  = require('child_process').spawn
yaml   = require 'js-yaml'
fs     = require 'fs'

module.exports = (config) ->

  buildScriptPaths = (instance) ->
    [scriptDir = "#{config.scriptBaseDir}/#{instance}", "#{scriptDir}/docker-compose.yml"]

  start: (instance, composition) ->
    eventEmitter = new events.EventEmitter()
    compose = yaml.safeDump composition
    [scriptDir, scriptPath] = buildScriptPaths instance

    pullCb = (data) ->
      data = data.toString()
      if m = data.match /(.+): Pulling from (.+)/i
        [all, version, image] = m
        eventEmitter.emit 'pulling', {image: image, version: version}
      else console.log 'pull output unknown', data
    upCb = (data) -> console.log 'UP', data.toString()

    ensureMkdir scriptDir, ->
      writeFile scriptPath, compose, ->
        runCmd 'docker-compose', ['-f', scriptPath, '-p', instance, 'pull'], pullCb, ->
          runCmd 'docker-compose', ['-f', scriptPath, '-p', instance, 'up', '-d', '--remove-orphans'], upCb, ->
            console.log 'Done, started', instance
    eventEmitter

  stop: (instance) ->
    [scriptDir, scriptPath] = buildScriptPaths instance

    cb = (data) ->
      console.log 'dc down', data.toString()

    runCmd 'docker-compose', ['-f', scriptPath, '-p', instance, 'down', '--remove-orphans'], cb, ->
      console.log 'Done, stopped', instance

#
# Helper functions to write files and run processes
#

runCmd = (cmd, args, stdoutCb, exitCb) ->
  spawned = spawn cmd, args
  if spawned.error
    console.error "Error, unable to execute", cmd, args, pull.error
  else
    console.log 'success', cmd, args
    spawned.stdout.on 'data', stdoutCb
    spawned.stderr.on 'data', (data) -> console.log 'stderr', data.toString()
    spawned.stdout.on 'end', exitCb

ensureMkdir = (scriptDir, success) ->
  fs.mkdir scriptDir, (err) ->
    unless not err or err.code is 'EEXIST'
      console.log 'Cannot make dir', scriptDir, err
    else
      success()

writeFile = (path, contents, success) ->
  fs.writeFile path, contents, (err) ->
    if err then console.error 'Error writing file', err
    else success()
