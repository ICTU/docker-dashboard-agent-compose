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

require('./lib/storage') agent, mqtt, config
