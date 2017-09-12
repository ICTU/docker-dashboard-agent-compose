assert  = require 'assert'
td      = require 'testdouble'

fs = null
storageLib = null
storage = null

describe 'Storage', ->

  beforeEach ->
    fs          = td.replace 'fs-extra'
    storageLib  = td.replace '../../src/coffee/storage/lib.coffee'
    storage     = require '../../src/coffee/storage.coffee'

  afterEach -> td.reset()

  it 'should call remoteFS rm when when /storage/delete is invoked', ->
    agent = td.object ['on']
    captor = td.matchers.captor()
    storage agent, null, dataDir: '/rootDir', domain: 'myDomain', remotefsUrl: 'remotefsUrl', docker: graph: path: '/docker/graph'
    td.verify agent.on '/storage/delete', captor.capture()
    captor.value {name:'name1'}, null, 'mycallback'
    td.verify storageLib.remoteFs 'remotefsUrl', 'rm', {name:'name1'}, 'mycallback'

  it 'should create a new storage bucket when /storage/create is invoked', ->
    agent = td.object ['on']
    captor = td.matchers.captor()
    storage agent, null, dataDir: '/rootDir', domain: 'myDomain', remotefsUrl: 'remotefsUrl', docker: graph: path: '/docker/graph'
    td.verify agent.on '/storage/create', captor.capture()
    captor.value null, {name: 'bucket1'}, 'mycallback'
    td.verify storageLib.remoteFs 'remotefsUrl', 'mk', {name: 'bucket1'}, 'mycallback'

  it 'should create new storage bucket by copying an existing bucket when /storage/create with source parameter is invoked', ->
    agent = td.object ['on']
    captor = td.matchers.captor()
    storage agent, null, dataDir: '/rootDir', domain: 'myDomain', remotefsUrl: 'remotefsUrl', docker: graph: path: '/docker/graph'
    td.verify agent.on '/storage/create', captor.capture()
    captor.value null, {name: 'bucket1', source: 'src1'}, 'mycallback'
    td.verify storageLib.remoteFs 'remotefsUrl', 'cp', {destination: 'bucket1', source: 'src1'}, 'mycallback'

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
