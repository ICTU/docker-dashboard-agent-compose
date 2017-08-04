_       = require 'lodash'
spawn   = require('child_process').spawn
mkdirp  = require 'mkdirp'
fs      = require 'fs'

module.exports =
  #
  # Takes in a depends_on list or object and always outputs a depends_on object.
  # When transformation form a list to an object is required it will add each
  # list item as a key on the new object and set the condition parameter.
  #
  transformDependsOnToObject: (depends_on, condition = 'service_started') ->
    if depends_on
      if depends_on.length?
        _.zipObject depends_on, depends_on.map -> condition: condition
      else depends_on
    else null

  saveScript: (config, filename, instance, scriptData, cb) ->
    [scriptDir] = buildScriptPaths config, instance
    scriptPath = "#{scriptDir}/#{filename}"
    ensureMkdir scriptDir, -> writeFile scriptPath, scriptData, cb
    scriptPath

  buildScriptPaths: buildScriptPaths = (config, instance) ->
    [scriptDir = "#{config.compose.scriptBaseDir}/#{config.domain}/#{instance}", "#{scriptDir}/docker-compose.yml"]

  ensureMkdir: ensureMkdir = (scriptDir, success) ->
    mkdirp scriptDir, (err) ->
      unless not err or err.code is 'EEXIST'
        console.log 'Cannot make dir', scriptDir, err
      else
        success?()

  writeFile: writeFile = (path, contents, success) ->
    fs.writeFile path, contents, (err) ->
      if err then console.error 'Error writing file', err
      else success null, path

  runCmd: (cmd, args, env, callbacks, exitCb) ->
    spawned = spawn cmd, args, env: (_.extend {}, process.env, env)
    if spawned.error
      console.error "Error, unable to execute", cmd, args, spawned.error
    else
      console.log 'success', cmd, args
      spawned.stdout.on 'data', callbacks.stdout if callbacks.stdout
      spawned.stderr.on 'data', callbacks.stderr if callbacks.stderr
      spawned.on 'close', () -> 
        if spawned.exitCode == 0
          exitCb()
        else 
          callbacks.stderr 'Something went wrong while pulling images.' if callbacks.stderr
