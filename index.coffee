fs            = require 'fs-extra'
path          = require 'path'
Mqtt          = require '@bigboat/mqtt-client'
server        = require './src/coffee/server'
env           = require './src/coffee/env'
packageJson   = require './package.json'

graphScanEnabled = env.get 'GRAPH_SCAN_ENABLED', true
if graphScanEnabled is 'false' then graphScanEnabled = false

config =
  domain: env.assert 'DOMAIN'
  tld: env.assert 'TLD'
  dataDir: env.assert 'DATA_DIR'
  docker:
    graph:
      path: env.get 'DOCKER_GRAPH_PATH', '/var/lib/docker'
  compose:
    scriptBaseDir: env.assert 'SCRIPT_BASE_DIR'
  network:
    name: env.assert 'NETWORK_NAME'
  graph:
    scanEnabled: graphScanEnabled
  httpPort: process.env.HTTP_PORT or 80
  authToken: process.env.AUTH_TOKEN

unless config.authToken
  console.error "AUTH_TOKEN is required!"
  process.exit 1

console.log 'Config \n\n', config, '\n\n'

try
  fs.mkdirSync (projectDataPath = path.join config.dataDir, config.domain)
catch err
  unless err.code is 'EEXIST'
    console.error 'Unable to create project data directory', projectDataPath
    process.exit 1

libcompose = (require './src/coffee/compose') config

mqtt = Mqtt()

publishSystemMem = (data) -> mqtt.publish '/system/memory', data
publishSystemUptime = (data) -> mqtt.publish '/system/uptime', data
publishSystemCpu = (data) -> mqtt.publish '/system/cpu', data
require('./src/js/os-monitor')(publishSystemMem, publishSystemUptime, publishSystemCpu)

compose = require('./src/coffee/compose/actions') config

agent = server {name: packageJson.name , version: packageJson.version}, config
agent.on 'start', (data) ->
  instanceName = data.instance.name
  options = data.instance.options

  compose.config instanceName, data.app.definition, data, (err, composev2) ->
    if err
      mqtt.publish '/agent/docker/log/startup/error',
        instance: instanceName
        data: err
    else
      composition = libcompose.augmentCompose instanceName, options, composev2

      start = compose.start instanceName, composition, data
      start.on 'pulling', (event) ->
        event.instance = instanceName
        mqtt.publish '/agent/docker/pulling', event
      start.on 'startup-log', (logData) ->
        event =
          instance: instanceName
          data: logData
        mqtt.publish '/agent/docker/log/startup', event

agent.on 'stop', (data) ->
  instanceName = data.instance.name
  stop = compose.stop instanceName, data
  stop.on 'teardown-log', (logData) ->
    event =
      instance: instanceName
      data: logData
    mqtt.publish '/agent/docker/log/teardown', event

require('./src/coffee/storage') agent, mqtt, config
