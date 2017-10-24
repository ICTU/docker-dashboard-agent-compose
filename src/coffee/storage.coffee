path  = require 'path'

{runPeriodically, publishDataStoreUsage} = require './storage/lib.coffee'

module.exports = (agent, mqtt, config) ->
  if config.graph?.scanEnabled
    runPeriodically publishDataStoreUsage(mqtt, '/agent/docker/graph', config.docker.graph.path)
