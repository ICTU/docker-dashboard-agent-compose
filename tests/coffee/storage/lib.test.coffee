assert   = require 'assert'
td       = require 'testdouble'
request  = td.replace 'request'
exec     = td.replace('child_process').exec
lib      = require '../../../src/coffee/storage/lib.coffee'

describe 'Storage/Lib', ->
  describe 'listStorageBuckets', ->
    it 'should callback with an error when there was a problem listing files in the dir', ->
      fs = td.object ['readdir']
      cb = td.function()
      td.when(fs.readdir 'mydir').thenCallback('err', null)
      lib.listStorageBuckets fs, 'mydir', cb
      td.verify cb 'err', null
    it 'should callback with an error when there was a problem retrieving file stats', ->
      fs = td.object ['readdir', 'statSync']
      cb = td.function()
      td.when(fs.readdir 'mydir').thenCallback( null, ['dir1', '.dir1.delete.lock'])
      td.when(fs.statSync 'mydir/dir1').thenThrow 'An Error'
      lib.listStorageBuckets fs, 'mydir', cb
      td.verify cb 'An Error', null
    it 'should retrieve stats for each file', ->
      fs = td.object ['readdir', 'statSync']
      cb = td.function()
      td.when(fs.readdir 'mydir').thenCallback( null, ['file1', 'file2'])
      lib.listStorageBuckets fs, 'mydir', cb
      td.verify fs.statSync('mydir/file1'), times:1
      td.verify fs.statSync('mydir/file2'), times:1
    it 'should return stats for directories only', ->
      fs = td.object ['readdir', 'statSync']
      cb = td.function()
      td.when(fs.readdir 'mydir').thenCallback( null, ['dir1', 'file2'])
      td.when(fs.statSync 'mydir/dir1').thenReturn isDirectory:(-> true), birthtime: 'sometime'
      td.when(fs.statSync 'mydir/file2').thenReturn isDirectory: -> false
      lib.listStorageBuckets fs, 'mydir', cb
      td.verify cb null, [
        name: 'dir1'
        created: 'sometime'
        isLocked: false
      ]
    it 'should set the isLocked property to true for directories which are locked by a copy lock', ->
      fs = td.object ['readdir', 'statSync']
      cb = td.function()
      td.when(fs.readdir 'mydir').thenCallback( null, ['dir1', '.dir1.copy.lock'])
      td.when(fs.statSync 'mydir/dir1').thenReturn isDirectory:(-> true), birthtime: 'sometime'
      lib.listStorageBuckets fs, 'mydir', cb
      td.verify cb null, [
        name: 'dir1'
        created: 'sometime'
        isLocked: true
      ]
    it 'should set the isLocked property to true for directories which are locked by a delete lock', ->
      fs = td.object ['readdir', 'statSync']
      cb = td.function()
      td.when(fs.readdir 'mydir').thenCallback( null, ['dir1', '.dir1.delete.lock'])
      td.when(fs.statSync 'mydir/dir1').thenReturn isDirectory:(-> true), birthtime: 'sometime'
      lib.listStorageBuckets fs, 'mydir', cb
      td.verify cb null, [
        name: 'dir1'
        created: 'sometime'
        isLocked: true
      ]

  describe 'remoteFs', ->
    it 'should call the remoteFs endpoint with the desired command and return its response to the caller', ->
      cb = td.function()
      td.when(request({
        url: 'remoteFsUrl/fs/some-cmd'
        method: 'POST'
        json: 'payload'}
      )).thenCallback null, null, 'mydata'
      lib.remoteFs 'remoteFsUrl', 'some-cmd', 'payload', cb
      td.verify cb null, 'mydata'

  describe 'publishDataStoreUsage', ->
    it 'should', ->
      mqtt = td.object ['publish']
      td.when(exec "df -B1 mydir | tail -1 | awk '{ print $2 }{ print $3}{ print $5}'" ).thenCallback null, "1\n2\n3"
      lib.publishDataStoreUsage(mqtt, 'mydir')()
      td.verify mqtt.publish '/agent/storage/size',
        name: 'mydir'
        total: "1"
        used: "2"
        percentage: "3"
