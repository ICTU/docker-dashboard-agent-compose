assert   = require 'assert'
td       = require 'testdouble'
request  = td.replace 'request'
exec     = td.replace('child_process').exec
lib      = require '../../../src/coffee/storage/lib.coffee'

describe 'Storage/Lib', ->

  after -> td.reset()

  describe 'remoteFs', ->
    it 'should call the remoteFs endpoint with the desired command and return its response to the caller', ->
      cb = td.function()
      td.when(request({
        url: 'remoteFsUrl/fs/some-cmd'
        method: 'POST'
        timeout: 3600000
        json: 'payload'}
      )).thenCallback null, null, 'mydata'
      lib.remoteFs 'remoteFsUrl', 'some-cmd', 'payload', cb
      td.verify cb null, 'mydata'

  describe 'publishDataStoreUsage', ->
    it 'should publish store usage details', ->
      mqtt = td.object ['publish']
      td.when(exec "df -B1 mydir | tail -1 | awk '{ print $2 }{ print $3}{ print $5}'" ).thenCallback null, "1\n2\n3"
      lib.publishDataStoreUsage(mqtt, '/agent/storage/size', 'mydir')()
      td.verify mqtt.publish '/agent/storage/size',
        name: 'mydir'
        total: "1"
        used: "2"
        percentage: "3"
