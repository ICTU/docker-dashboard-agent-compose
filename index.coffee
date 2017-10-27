fs            = require 'fs-extra'
path          = require 'path'
server        = require 'docker-dashboard-agent-api'
Mqtt          = require '@bigboat/mqtt-client'
env           = require './src/coffee/env'
packageJson   = require './package.json'

ENABLE_NETWORK_HEALTHCHECK = env.get 'ENABLE_NETWORK_HEALTHCHECK', false
NETWORK_HEALTHCHECK_TEST_INTERFACE = env.get 'NETWORK_HEALTHCHECK_TEST_INTERFACE', 'eth0'
NETWORK_HEALTHCHECK_TEST_IP_PREFIX = env.get 'NETWORK_HEALTHCHECK_TEST_IP_PREFIX', '10.25'

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
    parentNic: env.assert 'NETWORK_PARENT_NIC'
    scanEnabled: env.get 'NETWORK_SCAN_ENABLED', 'true'
    scanInterval: parseInt(env.get 'NETWORK_SCAN_INTERVAL', '60000')
  dhcp:
    scanInterval: parseInt(env.get 'DHCP_SCAN_INTERVAL', '5000')
    scanEnabled: env.get 'DHCP_SCAN_ENABLED', 'true'
  net_container:
    image: env.get 'NETWORK_IMAGE', 'ictu/pipes:2'
    startcheck:
      test: "ifconfig #{NETWORK_HEALTHCHECK_TEST_INTERFACE} | grep inet | grep #{NETWORK_HEALTHCHECK_TEST_IP_PREFIX}"
  graph:
    scanEnabled: graphScanEnabled

if ENABLE_NETWORK_HEALTHCHECK and ENABLE_NETWORK_HEALTHCHECK isnt 'false'
  config.net_container.healthcheck =
      test: env.get 'NETWORK_HEALTHCHECK_TEST', "ifconfig #{NETWORK_HEALTHCHECK_TEST_INTERFACE} | grep inet | grep #{NETWORK_HEALTHCHECK_TEST_IP_PREFIX}"
      interval:  env.get 'NETWORK_HEALTHCHECK_INTERVAL', '30s'
      timeout: env.get 'NETWORK_HEALTHCHECK_TIMEOUT', '5s'
      retries: parseInt(env.get 'NETWORK_HEALTHCHECK_RETRIES', 4)

console.log 'Config \n\n', config, '\n\n'

try
  fs.mkdirSync (projectDataPath = path.join config.dataDir, config.domain)
catch err
  unless err.code is 'EEXIST'
    console.error 'Unable to create project data directory', projectDataPath
    process.exit 1

libcompose = (require './src/coffee/compose') config

mqtt = Mqtt()

publishState = (instance, state) ->
  mqtt.publish '/instance/state', {instance: instance, state: state}

publishNetworkInfo = (data) -> mqtt.publish '/network/info', data
unless config.network.scanEnabled is 'false'
  config.network.scanCmd = env.assert 'NETWORK_SCAN_CMD'
network = require('./src/js/network')(config, publishNetworkInfo)
# network.createProjectNet()
network.scan() unless config.network.scanEnabled is 'false'

unless config.dhcp.scanEnabled is 'false'
  publishDhcpInfo = (data) -> mqtt.publish '/dhcp/info', data
  (require './src/js/dhcp') config, publishDhcpInfo

publishSystemMem = (data) -> mqtt.publish '/system/memory', data
publishSystemUptime = (data) -> mqtt.publish '/system/uptime', data
publishSystemCpu = (data) -> mqtt.publish '/system/cpu', data
require('./src/js/os-monitor')(publishSystemMem, publishSystemUptime, publishSystemCpu)

compose = require('./src/coffee/compose/actions') config

agent = server.agent name: packageJson.name , version: packageJson.version
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
