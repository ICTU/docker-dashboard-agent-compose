fs    = require 'fs-extra'
path  = require 'path'

lib   = require './storage/lib.coffee'

module.exports = (agent, mqtt, config) ->
  publish = lib.remoteFs mqtt

  if config.graph?.scanEnabled
    lib.runPeriodically lib.publishDataStoreUsage(mqtt, '/agent/docker/graph', config.docker.graph.path)

  agent.on '/storage/delete', ({name}) ->
    console.log "Requesting removal of storage bucket '#{name}'"
    publish 'delete', {name: name}

  agent.on '/storage/create', (params, {name, source}) ->
    if source
      console.log "Requesting copy of storage bucket '#{source}' to '#{name}'"
      publish 'copy', {source: source, destination: name}
    else
      console.log "Requesting a new bucket '#{name}'"
      publish 'create', {name: name}

  agent.on '/storage/size', ->
    console.log "Retrieving size of storage buckets is now automatic and near real-time."
