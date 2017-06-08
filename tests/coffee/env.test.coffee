assert  = require 'assert'
td      = require 'testdouble'
env     = require '../../src/coffee/env.coffee'

describe 'Env', ->
  describe 'assert', ->
    it 'should return the value of an environment variable when it exists', ->
      process.env['key'] = 'value'
      assert.equal env.assert('key'), 'value'

    it 'should log an error and exit the application when a variable doesnt exist', ->
      process = td.object env: {}, exit: (->)
      console = td.object error: ->
      env._assert process, console, 'nonexistingkey'
      td.verify(process.exit(1))
      td.verify console.error 'Error: Environment variable \'nonexistingkey\' not set.'

  describe 'get', ->
    it 'should return the value of an environment variable', ->
      process.env['key'] = 'value123'
      assert.equal env.get('key', 'default'), 'value123'

    it 'should return the default argument if the environment variable is not set', ->
      assert.equal env.get('nonexistingkey', 'default123'), 'default123'
