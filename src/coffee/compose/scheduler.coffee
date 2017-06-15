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

  started = [] # services that are started but are not yet done
  done = []    # services that are started and all startChecks are complete
  serviceRampUp = _.debounce ->
    readyToStart = []
    for service of services
      deps = graph.dependenciesOf(service)
      # start this service if:
      # 1. this service doesn't have dependencies or all dependencies are done
      # 2. this service is not already started
      if (_.difference deps, done).length is 0 and service not in started
        readyToStart.push service
    console.log 'readyToStart', readyToStart
    start readyToStart if readyToStart.length isnt 0
  , 500

  # the service is sucessfully started
  serviceStarted = (service) ->
    console.log 'serviceStarted', service
    done = _.union done, [service]
    console.log 'done', done
    setTimeout serviceRampUp, 0
  # the service has failed
  serviceFailed = (service, retries) ->
    console.log 'serviceFailed', service


  # runs the startCheck until it succeeds or maxes out the retries
  runStartCheck = (service, condition, interval, timeout, retries) ->
    tries = 0
    f = ->
      console.log 'runStartCheck', service, interval, timeout, retries, condition
      eventEmitter.emit 'runStartCheck', service, condition, timeout, (err) ->
        tries = tries + 1
        if err
          console.log 'start check failed', service, condition
          if tries <= retries
            setTimeout f, interval
          else
            console.log 'Too many tries', tries, ' Giving up on', service
            eventEmitter.emit 'serviceStartCheckFailed', service, retries, services[service]
            serviceFailed service, retries
        else
          console.log 'start check succeeded', service, condition
          eventEmitter.emit 'serviceStartCheckSucceeded', service, services[service]
          serviceStarted service
    setTimeout f, interval

  # schedules the startCheck if any
  scheduleStartCheck = (service) ->
    if condition = services[service].labels['bigboat.startcheck.condition']
      interval = parseInt services[service].labels['bigboat.startcheck.interval']
      timeout = parseInt services[service].labels['bigboat.startcheck.timeout']
      retries = parseInt services[service].labels['bigboat.startcheck.retries']

      runStartCheck service, condition, interval, timeout, retries
    else
      console.log 'service has no startcheck:', service
      serviceStarted service

  # emits a startComposeServices and schedules startChecks for these services
  start = (services) ->
    eventEmitter.emit 'startComposeServices', services, ->
      for service in services
        started.push service
        scheduleStartCheck service

  setTimeout serviceRampUp, 0
  eventEmitter
