assert  = require 'assert'
td      = require 'testdouble'

fs = null
storageLib = null
storage = null
chokidar = null

chokidarWatchOpts =
  usePolling: true
  ignored: "/rootDir/myDomain/*/**"

chokidarWatchOn = td.function 'chokidar.watch.on'

describe 'Storage', ->

  beforeEach ->
    fs          = td.replace 'fs-extra'
    chokidar    = td.replace 'chokidar'
    storageLib  = td.replace '../../src/coffee/storage/lib.coffee'
    storage     = require '../../src/coffee/storage.coffee'
    td.when(chokidar.watch(td.matchers.contains("/rootDir/myDomain"), chokidarWatchOpts)).thenReturn
      on: chokidarWatchOn

  afterEach -> td.reset()

  it 'should publish storage buckets to mqtt when /storage/list is invoked', ->
    agent = td.object ['on']
    mqtt = td.object ['publish']
    cb = td.function()
    td.when(agent.on('/storage/list')).thenCallback 'params', 'data', cb
    argIsFs = td.matchers.argThat (arg) -> arg is fs
    td.when(storageLib.listStorageBuckets argIsFs, '/rootDir/myDomain').thenCallback null, 'mybuckets'
    storage agent, mqtt, dataDir: '/rootDir', domain: 'myDomain', docker: graph: path: '/docker/graph'
    td.verify mqtt.publish '/agent/storage/buckets', 'mybuckets'

  it 'should delete a storage bucket when /storage/delete is invoked', ->
    agent = td.object ['on']
    captor = td.matchers.captor()
    storage agent, null, dataDir: '/rootDir', domain: 'myDomain', remotefsUrl: 'remotefsUrl', docker: graph: path: '/docker/graph'
    td.verify agent.on '/storage/delete', captor.capture()
    captor.value {name:'name1'}, null, 'mycallback'
    td.verify fs.writeFile '/rootDir/myDomain/.name1.delete.lock', td.matchers.anything(), captor.capture()
    captor.value()
    td.verify storageLib.remoteFs 'remotefsUrl', 'rm', {dir: '/myDomain/name1'}, captor.capture()
    captor.value()
    td.verify fs.unlink '/rootDir/myDomain/.name1.delete.lock', 'mycallback'

  it 'should create a new storage bucket when /storage/create is invoked', ->
    agent = td.object ['on']
    captor = td.matchers.captor()
    storage agent, null, dataDir: '/rootDir', domain: 'myDomain', remotefsUrl: 'remotefsUrl', docker: graph: path: '/docker/graph'
    td.verify agent.on '/storage/create', captor.capture()
    captor.value null, {name: 'bucket1'}, 'mycallback'
    td.verify fs.mkdirs '/rootDir/myDomain/bucket1', 'mycallback'

  it 'should create new storage bucket by copying an existing bucket when /storage/create with source parameter is invoked', ->
    agent = td.object ['on']
    captor = td.matchers.captor()
    storage agent, null, dataDir: '/rootDir', domain: 'myDomain', remotefsUrl: 'remotefsUrl', docker: graph: path: '/docker/graph'
    td.verify agent.on '/storage/create', captor.capture()
    captor.value null, {name: 'bucket1', source: 'src1'}, 'mycallback'
    td.verify fs.writeFile '/rootDir/myDomain/.bucket1.copy.lock', td.matchers.anything(), captor.capture()
    captor.value()
    td.verify storageLib.remoteFs 'remotefsUrl', 'cp', {source: '/myDomain/src1', destination: '/myDomain/bucket1'}, captor.capture()
    captor.value()
    td.verify fs.unlink '/rootDir/myDomain/.bucket1.copy.lock', 'mycallback'

  it 'should report the size of a storage bucket when /storage/size is invoked', ->
    agent = td.object ['on']
    cb = td.function()
    captor = td.matchers.captor()
    storage agent, null, dataDir: '/rootDir', domain: 'myDomain', remotefsUrl: 'remotefsUrl', docker: graph: path: '/docker/graph'
    td.verify agent.on '/storage/size', captor.capture()
    captor.value {name: 'bucket1'}, null, cb
    td.verify fs.writeFile '/rootDir/myDomain/.bucket1.size.lock', td.matchers.anything(), captor.capture()
    captor.value()
    td.verify storageLib.remoteFs 'remotefsUrl', 'du', {dir: '/myDomain/bucket1'}, captor.capture()
    captor.value null, {size: 1234}
    td.verify fs.unlink '/rootDir/myDomain/.bucket1.size.lock', captor.capture()
    captor.value()
    td.verify cb null, {name: 'bucket1', size: 1234}

  it 'should periodically publish data storage statistics to mqtt if data store scan is enabled', ->
    agent = td.object ['on']
    storage agent, null,
      dataDir: '/rootDir'
      domain: 'myDomain'
      docker:
        graph: path: '/docker/graph'
      datastore: scanEnabled: true
    td.verify storageLib.publishDataStoreUsage(null, '/agent/storage/size', '/rootDir')
    td.verify storageLib.runPeriodically td.matchers.anything()

  it 'should periodically publish docker graph statistics to mqtt if data store scan is enabled', ->
    agent = td.object ['on']
    storage agent, null,
      dataDir: '/rootDir'
      domain: 'myDomain'
      docker:
        graph: path: '/docker/graph'
      datastore: scanEnabled: true
    td.verify storageLib.publishDataStoreUsage(null, '/agent/docker/graph', '/docker/graph')
    td.verify storageLib.runPeriodically td.matchers.anything()

  it 'should NOT periodically publish data storage statistics to mqtt if data store scan is disabled', ->
    agent = td.object ['on']
    storage agent, null,
      dataDir: '/rootDir'
      domain: 'myDomain'
      docker:
        graph: path: '/docker/graph'
      datastore: scanEnabled: false
    td.verify storageLib.publishDataStoreUsage(), {times: 0, ignoreExtraArgs: true}
    td.verify storageLib.runPeriodically(), {times: 0, ignoreExtraArgs: true}

  it 'should NOT periodically publish docker graph statistics to mqtt if data store scan is disabled', ->
    agent = td.object ['on']
    storage agent, null,
      dataDir: '/rootDir'
      domain: 'myDomain'
      docker:
        graph: path: '/docker/graph'
      datastore: scanEnabled: false
    td.verify storageLib.publishDataStoreUsage(), {times: 0, ignoreExtraArgs: true}
    td.verify storageLib.runPeriodically(), {times: 0, ignoreExtraArgs: true}

  it 'should watch for changes on the base path and publish storage buckets when data store scan is enabled', ->
    agent = td.object ['on']
    mqtt = td.object ['publish']
    argIsFs = td.matchers.argThat (arg) -> arg is fs
    captor = td.matchers.captor()

    storage agent, mqtt,
      dataDir: '/rootDir'
      domain: 'myDomain'
      docker: graph: path: '/docker/graph'
      datastore: scanEnabled: true
    td.verify chokidarWatchOn 'addDir', td.matchers.isA Function
    td.verify chokidarWatchOn 'unlinkDir', td.matchers.isA Function
    td.verify chokidarWatchOn 'add', td.matchers.isA Function
    td.verify chokidarWatchOn 'unlink', td.matchers.isA Function
    td.verify storageLib.listStorageBuckets argIsFs, '/rootDir/myDomain', captor.capture()
    captor.value null, 'some-buckets'
    td.verify mqtt.publish '/agent/storage/buckets', 'some-buckets'

  it 'should NOT watch for changes on the base path and publish storage buckets when data store scan is disabled', ->
    agent = td.object ['on']

    storage agent, null,
      dataDir: '/rootDir'
      domain: 'myDomain'
      docker: graph: path: '/docker/graph'
      datastore: scanEnabled: false
    td.verify fs.watch(), {times: 0, ignoreExtraArgs: true}
    td.verify storageLib.listStorageBuckets(), {times: 0, ignoreExtraArgs: true}
