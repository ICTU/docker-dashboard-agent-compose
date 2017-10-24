assert  = require 'assert'
td      = require 'testdouble'

storageLib = null
storage = null
publish = null
agent = null
captor = null

describe 'Storage', ->

  beforeEach ->
    storageLib  = td.replace '../../src/coffee/storage/lib.coffee'
    storage     = require '../../src/coffee/storage.coffee'

    publish = td.function('.publish')

    agent = td.object ['on']
    captor = td.matchers.captor()
    storage agent, "mqtt", {}

  afterEach -> td.reset()

  it 'should periodically publish docker graph statistics to mqtt if data store scan is enabled', ->
    agent = td.object ['on']
    storage agent, null,
      dataDir: '/rootDir'
      domain: 'myDomain'
      docker:
        graph: path: '/docker/graph'
      graph: scanEnabled: true
    td.verify storageLib.publishDataStoreUsage(null, '/agent/docker/graph', '/docker/graph')
    td.verify storageLib.runPeriodically td.matchers.anything()

  it 'should NOT periodically publish docker graph statistics to mqtt if data store scan is disabled', ->
    agent = td.object ['on']
    storage agent, null,
      dataDir: '/rootDir'
      domain: 'myDomain'
      docker: graph: path: '/docker/graph'
      graph: scanEnabled: false
    td.verify storageLib.publishDataStoreUsage(), {times: 0, ignoreExtraArgs: true}
    td.verify storageLib.runPeriodically(), {times: 0, ignoreExtraArgs: true}
