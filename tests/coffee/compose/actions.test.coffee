assert    = require 'assert'
td        = require 'testdouble'

actions = null
lib     = null
shell   = null

config =
  domain: 'google'
  tld: 'com'
instanceCfg =
  app:
    name: 'myapp'
    version: '1.0'
  instance: name: 'instance1'
compose = """
  version: '2.0'

  """
env = env:
  BIGBOAT_PROJECT: config.domain
  BIGBOAT_DOMAIN: config.domain
  BIGBOAT_TLD: config.tld
  BIGBOAT_APPLICATION_NAME: instanceCfg.app.name
  BIGBOAT_APPLICATION_VERSION: instanceCfg.app.version
  BIGBOAT_INSTANCE_NAME: instanceCfg.instance.name

describe 'Compose Actions', ->

  afterEach -> td.reset()

  beforeEach ->
    lib       = td.replace '../../../src/coffee/compose/lib.coffee'
    shell     = td.replace 'shelljs'
    shell.exec = td.function()
    Actions   = require '../../../src/coffee/compose/actions.coffee'
    actions = Actions config

  describe 'config', ->
    it 'should report all errors that come from running the compose file through `docker-compose config`', ->
      cb = td.function()
      captor = td.matchers.captor()
      actions.config 'instance1', {version: '2.0'}, instanceCfg, cb
      td.verify lib.saveScript config, 'docker-compose.original', 'instance1', compose, captor.capture()
      td.when(shell.exec 'docker-compose --file /the/path/to/docker-compose.original config', env).thenReturn code: -1, stderr: 'error'
      captor.value null, '/the/path/to/docker-compose.original'
      td.verify cb 'error'
    it 'should return the compose file after running it through `docker-compose config`', ->
      cb = td.function()
      captor = td.matchers.captor()
      actions.config 'instance1', {version: '2.0'}, instanceCfg, cb
      td.verify lib.saveScript config, 'docker-compose.original', 'instance1', compose, captor.capture()
      td.when(shell.exec 'docker-compose --file /the/path/to/docker-compose.original config', env).thenReturn code: 0, stdout: """version: '2.1'"""
      captor.value null, '/the/path/to/docker-compose.original'
      td.verify cb null, {version: '2.1'}

  describe 'start', ->
    it 'should start a docker compose file', ->
      captor = td.matchers.captor()
      actions.start 'instance1', {version: '2.0'}, instanceCfg
