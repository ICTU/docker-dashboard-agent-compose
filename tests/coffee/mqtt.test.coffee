assert = require 'assert'
td     = require 'testdouble'

realMqtt = td.replace 'mqtt'
mqtt   = require '../../src/coffee/mqtt.coffee'

config =
  url: 'mqtt://host'
  user: 'username'
  pass: 'passwd123'

client = null; myMqtt = null; console = null;

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

  it 'should log when connected to the server', ->
    captor = td.matchers.captor()
    td.verify client.on 'connect', captor.capture()
    captor.value()
    td.verify console.log 'Connected to', config.url

  it 'should log when an error occurs', ->
    captor = td.matchers.captor()
    td.verify client.on 'error', captor.capture()
    captor.value('myerr')
    td.verify console.log 'An error occured', 'myerr'

  it 'should log when the connection to the mqtt server is closed', ->
    captor = td.matchers.captor()
    td.verify client.on 'close', captor.capture()
    captor.value()
    td.verify console.log 'Connection closed'
