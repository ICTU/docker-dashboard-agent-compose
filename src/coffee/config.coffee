yaml  = require 'js-yaml'
env   = require './env'

graphScanEnabled = env.get 'GRAPH_SCAN_ENABLED', true
if graphScanEnabled is 'false' then graphScanEnabled = false

deployment_placement = JSON.parse env.get('DEPLOY_PLACEMENT', null)
deployment_placement ?= constraints: ['node.role == worker']

config =
  domain: env.assert 'DOMAIN'
  tld: env.assert 'TLD'
  dataDir: env.assert 'DATA_DIR'
  docker:
    graph:
      path: env.get 'DOCKER_GRAPH_PATH', '/var/lib/docker'
  swarm:
    deployment_placement: deployment_placement
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

module.exports = config
