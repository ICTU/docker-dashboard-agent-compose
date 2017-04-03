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

  it 'should publish storage buckets to mqtt when /storage/list is invoked', ->
    agent = td.object ['on']
    mqtt = td.object ['publish']
    cb = td.function()
    td.when(agent.on('/storage/list')).thenCallback 'params', 'data', cb
    argIsFs = td.matchers.argThat (arg) -> arg is fs
    td.when(storageLib.listStorageBuckets argIsFs, '/rootDir/myDomain').thenCallback null, 'mybuckets'
    storage agent, mqtt, dataDir: '/rootDir', domain: 'myDomain'
    td.verify mqtt.publish '/agent/storage/buckets', 'mybuckets'

  it 'should delete a storage bucket when /storage/delete is invoked', ->
    agent = td.object ['on']
    mqtt = td.object ['publish']
    argIsFs = td.matchers.argThat (arg) -> arg is fs
    captor = td.matchers.captor()
    storage agent, mqtt, dataDir: '/rootDir', domain: 'myDomain', remotefsUrl: 'remotefsUrl'
    td.verify agent.on '/storage/delete', captor.capture()
    captor.value {name:'name1'}, null, 'mycallback'
    td.verify fs.writeFile '/rootDir/myDomain/.name1.delete.lock', td.matchers.anything(), captor.capture()
    captor.value()
    td.verify storageLib.remoteFs 'remotefsUrl', 'rm', {dir: '/myDomain/name1'}, captor.capture()
    captor.value()
    td.verify fs.unlink '/rootDir/myDomain/.name1.delete.lock', 'mycallback'

  it 'should periodically publish data storage statistics to mqtt', ->
    agent = td.object ['on']
    storage agent, null, dataDir: '/rootDir', domain: 'myDomain'
    td.verify storageLib.runPeriodically td.matchers.anything()

  it 'should watch for changes on the base path and publish storage buckets', ->
    agent = td.object ['on']
    mqtt = td.object ['publish']
    argIsFs = td.matchers.argThat (arg) -> arg is fs
    captor = td.matchers.captor()

    storage agent, mqtt, dataDir: '/rootDir', domain: 'myDomain'
    td.verify fs.watch '/rootDir/myDomain', captor.capture()
    captor.value()
    td.verify storageLib.listStorageBuckets argIsFs, '/rootDir/myDomain', captor.capture()
    captor.value null, 'some-buckets'
    td.verify mqtt.publish '/agent/storage/buckets', 'some-buckets'
