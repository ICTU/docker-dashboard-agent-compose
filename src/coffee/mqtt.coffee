mqtt = require 'mqtt'
Etcd = require 'node-etcd'
etcd = new Etcd 'http://10.25.96.5:4001'

module.exports =
  connect: (config) -> _connect config, console
  _connect: _connect = (config, console) ->
    mqttConfig = config.mqtt
    client = mqtt.connect mqttConfig.url,
      username: mqttConfig.user
      password: mqttConfig.pass

    client.on 'connect', ->
      console.log 'Connected to', mqttConfig.url

    client.on 'error', (err) -> console.log 'An error occured', err
    client.on 'close', -> console.log 'Connection closed'

    client.subscribe '/docker/container/inspect'
    client.on 'message', (topic, data) ->
      info = JSON.parse data.toString()
      ip = info?.NetworkSettings?.Networks?[config.network.name]?.IPAddress
      if ip
        lbls = info?.Config?.Labels
        target = "#{lbls['bigboat.tld']}/#{lbls['bigboat.domain']}/#{lbls['bigboat.instance.name']}/#{lbls['bigboat.service.name']}"
        etcd.set "/skydns/#{target}", JSON.stringify(host: ip), (err) ->
          console.error err if err

    publish: (topic, data) ->
      client.publish topic, JSON.stringify data
