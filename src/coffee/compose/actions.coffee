events = require 'events'
yaml   = require 'js-yaml'
fs     = require 'fs'
mkdirp = require 'mkdirp'
shell  = require 'shelljs'
_      = require 'lodash'

lib    = require './lib.coffee'
ssh    = require './ssh'

shell.config.verbose = false
shell.config.silent = true

module.exports = (config) ->
  composeProject = (instance) -> "#{config.domain}-#{instance}".replace '.', '-'

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
    [scriptDir, scriptPath, scriptWithSshPath] = lib.buildScriptPaths config, instance
    composeProjectName = composeProject instance

    env = buildEnv config, data

    emitLogCb = (data) -> eventEmitter.emit 'startup-log', data.toString()

    volumePaths = []
    for service in _.values composition.services when service.volumes
      volumePaths = _.uniq (_.union volumePaths, service.volumes.map (mapping) ->
        splits = mapping.split(':')
        splits[0] if splits.length >= 2
      )

    for path in volumePaths when path
      try
        process.umask 0
        mkdirp.sync path
        fs.chmodSync path, 0o777
        console.log 'Created volume', path
      catch err
        console.log('Error while creating volume dir', err) unless err.code is 'EEXIST'

    lib.ensureMkdir scriptDir, ->
      lib.writeFile scriptPath, compose, ->
        console.log 'Starting', composeProjectName, 'from file', scriptPath
        args = ['stack', 'up', '-c', scriptPath, '--prune', '--resolve-image=always', composeProjectName]
        lib.runCmd 'docker', args, env, {stderr: emitLogCb, stdout: emitLogCb}, ->
          console.log 'Starting', composeProjectName

          bigboatComposeServices = _.omit data.app.bigboatCompose, 'name', 'version', 'pic', 'description'
          sshServices = {}
          for srvName, srv of bigboatComposeServices
            sshServices[srvName] = sshOpts if sshOpts = (srv.ssh or srv.enable_ssh)

          unless sshServices is {}
            for srvName, sshOpts of sshServices
              node = shell.exec "docker service ps #{composeProjectName}_#{srvName} | awk 'NR==2{print $4}'"
              node = node?.trim()
              if node
                sshSrv = ssh instance, srvName, node, sshOpts, config
                composition.services["#{srvName}-ssh"] = sshSrv

                console.log 'SSH:', JSON.stringify composition, null, 2
                composeWithSsh = yaml.safeDump composition
                lib.writeFile scriptWithSshPath, composeWithSsh, ->
                  args = ['stack', 'up', '-c', scriptWithSshPath, '--prune', '--resolve-image=always', composeProjectName]
                  lib.runCmd 'docker', args, env, {stderr: emitLogCb, stdout: emitLogCb}, ->
                    console.log 'Starting', composeProjectName, 'with SSH.'
              else
                console.error "Could not find the target service '#{composeProjectName}_#{srvName}' or the node it lives on."

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

    lib.runCmd 'docker', ['stack', 'down', composeProjectName], env, {stderr: emitLogCb, stdout: emitLogCb}, ->
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
