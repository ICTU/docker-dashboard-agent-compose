express         = require 'express'
bodyParser      = require 'body-parser'
passport        = require 'passport'
TokenStrategy   = require('passport-token-auth').Strategy
events          = require 'events'
_               = require 'lodash'

module.exports = (agentInfo, {httpPort, authToken}) ->
  eventEmitter = new events.EventEmitter()

  passport.use new TokenStrategy {}, (token, cb) ->
    cb null, authToken == token

  app = express()
  app.use passport.initialize()
  app.use bodyParser.json()
  app.use bodyParser.urlencoded extended: false
  authenticate = passport.authenticate('token', { session: false })

  emit = (action) -> (req, res) ->
    eventEmitter.emit action, req.params, req.body, (err, data) ->
      if err
        console.error err
        res.status(500).end('error')
      else
        res.status(200).json(data)

  run = (action) -> (req, res) ->
    data = req.body
    if data.app and data.instance
      eventEmitter.emit action, data
      res.status(200).end('thanks')
    else res.status(422).end 'appInfo not provided'

  app.post '/app/start', authenticate, run('start')
  app.post '/app/stop', authenticate, run('stop')

  sendPong = (req, res) -> res.end('pong')
  app.get '/ping', sendPong
  app.get '/auth-ping', authenticate, sendPong

  app.get '/version', (req, res) ->
    obj =
      api: (require '../../package.json').version
      agent: agentInfo

    res.end JSON.stringify obj

  server = app.listen httpPort, ->
    host = server.address().address
    port = server.address().port
    console.log 'Listening on http://%s:%s', host, port

  eventEmitter # return the eventEmitter so clients can register callbacks
