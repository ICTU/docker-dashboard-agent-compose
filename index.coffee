fs            = require 'fs-extra'
path          = require 'path'
server        = require 'docker-dashboard-agent-api'
Mqtt          = require './lib/mqtt'
env           = require './lib/env'
packageJson   = require './package.json'

config =
  vlan: env.assert 'VLAN'
  domain: env.assert 'DOMAIN'
  tld: env.assert 'TLD'
  dataDir: env.assert 'DATA_DIR'
  mqtt:
    url: env.assert 'MQTT_URL'
  compose:
    scriptBaseDir: env.assert 'SCRIPT_BASE_DIR'

console.log 'Config \n\n', config, '\n\n'

try
  fs.mkdirSync (projectDataPath = path.join config.dataDir, config.domain)
catch err
  unless err.code is 'EEXIST'
    console.error 'Unable to create project data directory', projectDataPath
    process.exit 1

libcompose = (require './lib/compose') config

mqtt = new Mqtt config.mqtt

publishState = (instance, state) ->
  mqtt.publish '/instance/state', {instance: instance, state: state}

compose = require('./lib/compose/actions') config.compose

agent = server.agent name: packageJson.name , version: packageJson.version
agent.on 'start', (data) ->
  console.log 'start', data
  instanceName = data.instance.name
  options = data.instance.options
  composition = libcompose.augmentCompose instanceName, options, data.app.definition
  start = compose.start instanceName, composition
  start.on 'pulling', (event) ->
    event.instance = instanceName
    mqtt.publish '/agent/docker/pulling', event

agent.on 'stop', (data) ->
  instanceName = data.instance.name
  compose.stop instanceName

agent.on '/storage/list', (params, data, callback) ->
  srcpath = path.join config.dataDir, config.domain
  dirList = fs.readdirSync srcpath
  files = dirList.map (file) ->
    stat = fs.statSync path.join(srcpath, file)
    if stat.isDirectory()
      name: file
      created: stat.birthtime
      isLocked: ".#{file}.copy.lock" in dirList
  .filter (file) -> file?
  callback null, files

agent.on '/storage/delete', ({name}, data, callback) ->
  srcpath = path.join config.dataDir, config.domain, name
  fs.remove srcpath, callback

agent.on '/storage/create', (params, {name, source}, callback) ->
  targetpath = path.join config.dataDir, config.domain, name
  if source
    srcpath = path.join config.dataDir, config.domain, source
    lockFile = path.join config.dataDir, config.domain, ".#{name}.copy.lock"
    fs.writeFile lockFile, "Copying #{srcpath} to #{targetpath}..."
    child_process.exec "cp -rp #{srcpath} #{targetpath}", ->
      fs.unlink lockFile, callback
  else
    fs.mkdirs targetpath, callback
