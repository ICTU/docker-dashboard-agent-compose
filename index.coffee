server        = require 'docker-dashboard-agent-api'
Mqtt          = require './lib/mqtt'
env           = require './lib/env'
packageJson   = require './package.json'

config =
  vlan: env.assert 'VLAN'
  domain: env.assert 'DOMAIN'
  mqtt:
    url: env.assert 'MQTT_URL'
  compose:
    scriptBaseDir: env.assert 'SCRIPT_BASE_DIR'

console.log 'Config \n\n', config, '\n\n'

libcompose = (require './lib/compose') config

mqtt = new Mqtt config.mqtt

publishState = (instance, state) ->
  mqtt.publish '/instance/state', {instance: instance, state: state}

compose = require('./lib/compose/actions') config.compose

agent = server.agent name: packageJson.name , version: packageJson.version
agent.on 'start', (data) ->
  instanceName = data.instance.name
  composition = libcompose.augmentCompose instanceName, (libcompose.appdef2compose instanceName, data.app.definition)
  start = compose.start instanceName, composition
  start.on 'pulling', (event) ->
    event.instance = instanceName
    mqtt.publish '/agent/docker/pulling', event

agent.on 'stop', (data) ->
  instanceName = data.instance.name
  compose.stop instanceName
