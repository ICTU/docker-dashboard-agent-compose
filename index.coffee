server        = require 'docker-dashboard-agent-api'
Mqtt          = require './lib/mqtt'
env           = require './lib/env'
packageJson   = require './package.json'

config =
  vlan: env.assert 'VLAN'
  domain: env.assert 'DOMAIN'
  mqtt:
    url: env.assert 'MQTT_URL'
  rancher:
    host: env.assert 'RANCHER_HOST'
    port: env.assert 'RANCHER_PORT'
    auth:
      key: env.assert 'RANCHER_KEY'
      secret: env.assert 'RANCHER_SECRET'

libcompose = (require './lib/compose') config

mqtt = new Mqtt config.mqtt

publishState = (instance, state) ->
  mqtt.publish '/instance/state', {instance: instance, state: state}

compose =
  events: null
  actions: require('./lib/compose/actions') config.rancher, publishState

agent = server.agent name: packageJson.name , version: packageJson.version
agent.on 'start', (data) ->
  instanceName = data.instance.name
  composition = libcompose.augmentCompose instanceName, (libcompose.appdef2compose instanceName, data.app.definition)
  compose.actions.start instanceName, composition

agent.on 'stop', (data) ->
  instanceName = data.instance.name
  compose.actions.stop instanceName
