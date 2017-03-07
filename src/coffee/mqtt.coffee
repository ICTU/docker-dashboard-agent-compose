mqtt    = require 'mqtt'

module.exports = (mqttConfig) ->
  client = mqtt.connect mqttConfig.url,
    username: mqttConfig.user
    password: mqttConfig.pass
  client.on 'connect', ->
    console.log 'Connected to', mqttConfig.url

  client.on 'error', (err) -> console.log 'An error occured', err
  client.on 'close', -> console.log 'Connection closed'

  publish: (topic, data) ->
    client.publish topic, JSON.stringify data
