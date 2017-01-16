require("./out/goog/bootstrap/nodejs");
require("./out/cljs/core")
require('./out/compose/compose')
goog.require("compose.compose")

fs            = require 'fs-extra'
path          = require 'path'
server        = require 'docker-dashboard-agent-api'
Mqtt          = require './src/coffee/mqtt'
env           = require './src/coffee/env'
packageJson   = require './package.json'

config =
  vlan: env.assertVlan 'VLAN'
  domain: env.assert 'DOMAIN'
  tld: env.assert 'TLD'
  dataDir: env.assert 'DATA_DIR'
  host_if: env.assert 'HOST_IF'
  remotefsUrl: env.assert 'REMOTEFS_URL'
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

libcompose = (require './src/coffee/compose') config

mqtt = new Mqtt config.mqtt

publishState = (instance, state) ->
  mqtt.publish '/instance/state', {instance: instance, state: state}

compose = require('./src/coffee/compose/actions') config

agent = server.agent name: packageJson.name , version: packageJson.version
agent.on 'start', (data) ->
  instanceName = data.instance.name
  options = data.instance.options
  composev2 = global.compose.compose.mapv2 data.app.definition
  composition = libcompose.augmentCompose instanceName, options, composev2
  console.log 'wiee!', composition
  console.log "============="
  start = compose.start instanceName, composition, data
  start.on 'pulling', (event) ->
    event.instance = instanceName
    mqtt.publish '/agent/docker/pulling', event

agent.on 'stop', (data) ->
  instanceName = data.instance.name
  compose.stop instanceName, data

require('./src/coffee/storage') agent, mqtt, config
