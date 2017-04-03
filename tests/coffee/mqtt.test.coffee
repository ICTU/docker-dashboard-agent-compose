assert = require 'assert'
td     = require 'testdouble'

realMqtt = td.replace 'mqtt'
mqtt   = require '../../src/coffee/mqtt.coffee'

config =
  url: 'mqtt://host'
  user: 'username'
  pass: 'passwd123'

client = null; myMqtt = null

describe 'mqtt', ->

  after -> td.reset()

  beforeEach ->
    client = td.object ['on', 'publish']
    td.when(realMqtt.connect('mqtt://host', {username: 'username', password: 'passwd123'})).thenReturn client
    console = td.object log: ->
    myMqtt = mqtt._connect config, console

  it '.connect() returns an mqtt instance with publish capacilities', ->
    assert.equal myMqtt.publish?, true
    myMqtt.publish 'myTopic', {some: 'data'}
    td.verify client.publish 'myTopic', '{"some":"data"}'
