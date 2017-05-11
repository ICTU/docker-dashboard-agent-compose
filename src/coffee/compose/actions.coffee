events = require 'events'
yaml   = require 'js-yaml'
fs     = require 'fs'
mkdirp = require 'mkdirp'
shell  = require 'shelljs'
_      = require 'lodash'

lib    = require './lib.coffee'

shell.config.verbose = false
shell.config.silent = true

module.exports = (config) ->

  composeProject = (instance) -> "#{config.domain}-#{instance}"

  config: (instance, compose, data, cb) ->
    lib.saveScript config, 'docker-compose.original', instance, yaml.safeDump(compose), (err, filePath) ->
      env = buildEnv config, data
      res = shell.exec("docker-compose --file #{filePath} config", env: env)
      if res.code is 0
        cb null, yaml.safeLoad res.stdout
      else cb res.stderr

  start: (instance, composition, data) ->
    eventEmitter = new events.EventEmitter()
    compose = yaml.safeDump composition
    [scriptDir, scriptPath] = lib.buildScriptPaths config, instance
    composeProjectName = composeProject instance

    pullCb = (data) ->
      data = data.toString()
      if m = data.match /(.+): Pulling from (.+)/i
        [all, version, image] = m
        eventEmitter.emit 'pulling', {image: image, version: version}
      else console.log 'pull output unknown', data
    upCb = (data) -> console.log 'UP', data.toString()

    env = buildEnv config, data

    emitLogCb = (data) -> eventEmitter.emit 'startup-log', data.toString()

    volumePaths = []
    for service in _.values composition.services when service.volumes
      volumePaths = _.uniq (_.union volumePaths, service.volumes).map (mapping) ->
        splits = mapping.split(':')
        splits[0] if splits.length is 2

    for path in volumePaths when path
      try
        process.umask 0
        mkdirp.sync path
        fs.chmodSync path, 0o777
        console.log 'Created volume', path
      catch err
        console.log('Error while creating volume dir', err) unless err.code is 'EEXIST'

    netContainerNames = _.filter _.keys(composition.services), (serviceName) -> serviceName.match /^bb\-net/
    serviceContainerNames = _.difference _.keys(composition.services), netContainerNames

    lib.ensureMkdir scriptDir, ->
      lib.writeFile scriptPath, compose, ->
        lib.runCmd 'docker-compose', ['-f', scriptPath, '-p', composeProjectName, 'pull'], env, {stdout: pullCb, stderr: emitLogCb}, ->
          args = _.concat ['-f', scriptPath, '-p', composeProjectName, 'up', '-d', '--remove-orphans'], netContainerNames
          lib.runCmd 'docker-compose', args, env, {stderr: emitLogCb}, ->

            startComposeServices = ->
              args = _.concat ['-f', scriptPath, '-p', composeProjectName, 'up', '-d', '--remove-orphans'], serviceContainerNames
              lib.runCmd 'docker-compose', args, env, {stderr: emitLogCb}, ->
                console.log 'Done, started', composeProjectName

            tries = 0
            checkNetworks = ->
              checkAgain = false
              for netContainer in netContainerNames
                tries = tries + 1
                res = shell.exec "docker-compose -f #{scriptPath} -p #{composeProjectName} exec #{netContainer} #{config.net_container.startcheck}"
                if res.code is 1 then checkAgain = true
              if checkAgain
                if tries <= 48 # we try for four minutes before giving up
                  setTimeout checkNetworks, 5000
                else emitLogCb 'Failed to acquire IPs for all services...'
              else startComposeServices()

            emitLogCb 'Network started, waiting for IPs...\n'
            checkNetworks()
    eventEmitter

  stop: (instance, data) ->
    eventEmitter = new events.EventEmitter()
    [scriptDir, scriptPath] = lib.buildScriptPaths config, instance
    composeProjectName = composeProject instance

    env = buildEnv config, data
    emitCbCalled = false
    emitLogCb = (data) ->
      emitCbCalled = true
      eventEmitter.emit 'teardown-log', data.toString()

    lib.runCmd 'docker-compose', ['-f', scriptPath, '-p', composeProjectName, 'down', '--remove-orphans'], env, {stderr: emitLogCb}, ->
      if emitCbCalled
        console.log 'Done, stopped', composeProjectName
      else
        # TODO: this fallback mechanism should be removed in future versions (e.g. v + 10), current(v)=2.0.1
        console.log "#{composeProjectName} did not stop, falling back on old stop behavior based on instance name only"
        lib.runCmd 'docker-compose', ['-f', scriptPath, '-p', instance, 'down', '--remove-orphans'], env, {stderr: emitLogCb}, ->
          console.log 'Done, stopped', composeProjectName

    eventEmitter

#
# Helper functions to write files and run processes
#

buildEnv = (cfg, instanceCfg) ->
  BIGBOAT_PROJECT: cfg.domain
  BIGBOAT_DOMAIN: cfg.domain
  BIGBOAT_TLD: cfg.tld
  BIGBOAT_APPLICATION_NAME: instanceCfg.app.name
  BIGBOAT_APPLICATION_VERSION: instanceCfg.app.version
  BIGBOAT_INSTANCE_NAME: instanceCfg.instance.name
