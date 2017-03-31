assert  = require 'assert'
td      = require 'testdouble'
lib     = require '../../../src/coffee/storage/lib.coffee'

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
