#
# Implements a scheduler for Docker Compose data structures using
# the BigBoat startcheck extension. The scheduler will ensure that services are
#    a. Started in the right order
#    b. Started only when its dependencies fulfill the startcheck condition (when present)
#

events   = require 'events'
_        = require 'lodash'
shell    = require 'shelljs'
DepGraph = require('dependency-graph').DepGraph

module.exports = (services) ->
  eventEmitter = new events.EventEmitter()
  graph = new DepGraph()
  # first we add all nodes to the graph
  graph.addNode(service) for service of services


  # then we add all dependency constraints to the graph
  for service of services
    depends_on = Object.keys(services[service]?.depends_on or [])
    graph.addDependency service, serviceConstraint for serviceConstraint in depends_on

  # we now have a dependency graph with all services and their dependencies

  started = []
  serviceRampUp = _.debounce ->
    readyToStart = []
    for service of services
      deps = graph.dependenciesOf(service)
      # if this service doesn't have dependencies or all dependencies are started, this service can be started too
      if (_.difference deps, started).length is 0 and service not in started
        readyToStart.push service
    console.log 'readyToStart', readyToStart
    start readyToStart if readyToStart.length isnt 0
  , 500

  serviceStarted = (service) ->
    console.log 'serviceStarted', service
    started = _.union started, [service]
    setTimeout serviceRampUp, 0

  runStartCheck = (service, condition, interval) ->
    handle = setInterval ->
      eventEmitter.emit 'runStartCheck', service, condition, (err) ->
        if err
          console.log 'start check failed', service, condition
        else
          console.log 'start check succeeded', service, condition
          clearInterval handle
          serviceStarted service
    , parseInt interval

  scheduleStartCheck = (service) ->
    if condition = services[service].labels['bigboat.startcheck.condition']
      interval = services[service].labels['bigboat.startcheck.interval']
      runStartCheck service, condition, interval
    else
      console.log 'service has no startcheck:', service
      serviceStarted service

  start = (services) ->
    eventEmitter.emit 'startComposeServices', services, ->
      scheduleStartCheck service for service in services

  setTimeout serviceRampUp, 0
  eventEmitter
