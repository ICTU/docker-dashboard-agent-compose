assert   = require 'assert'
td       = require 'testdouble'
exec     = td.replace('child_process').exec
lib      = require '../../../src/coffee/storage/lib.coffee'

describe 'Storage/Lib', ->

  after -> td.reset()

  describe 'remoteFs', ->
    it 'should send the correct command over MQTT', ->
      mqtt = td.object ['publish']
      data = some: 'thing'
      lib.remoteFs(mqtt) 'cmd', data
      td.verify mqtt.publish '/commands/remotefs/cmd', data, {retain: false, qos: 2}

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
