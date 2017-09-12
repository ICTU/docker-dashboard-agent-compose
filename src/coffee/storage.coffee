fs    = require 'fs-extra'
path  = require 'path'

lib   = require './storage/lib.coffee'

module.exports = (agent, mqtt, config) ->
  if config.graph?.scanEnabled
    lib.runPeriodically lib.publishDataStoreUsage(mqtt, '/agent/docker/graph', config.docker.graph.path)

  agent.on '/storage/delete', (params, data, callback) ->
    console.log "Requesting removal of storage bucket '#{params.name}'"
    lib.remoteFs config.remotefsUrl, 'rm', params, callback

  agent.on '/storage/create', (params, {name, source}, callback) ->
    if source
      console.log "Requesting copy of storage bucket '#{source}' to '#{name}'"
      lib.remoteFs config.remotefsUrl, 'cp', {source: source, destination: name}, callback
    else
      console.log "Requesting a new bucket '#{name}'"
      lib.remoteFs config.remotefsUrl, 'mk', {name}, callback

  agent.on '/storage/size', ({name}, data, callback) ->
    console.log "Retrieving size of storage buckets is now automatic and near real-time."
