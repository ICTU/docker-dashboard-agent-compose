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

  describe 'assertVlan', ->
    vlanTest = (vlan) -> it "vlan #{vlan}", ->
      process = td.object env: {vlan: vlan}, exit: ->
      assert.equal env._assertVlan(process, null, 'vlan'), vlan
      td.verify process.exit(1), {times: 0}
    describe 'should accept', ->
      vlanTest "#{i}" for i in [1..4095] by 100
      vlanTest '4095'

    negativeVlanTest = (vlan) -> it "vlan #{vlan}", ->
      process = td.object env: {vlan: vlan}, exit: ->
      console = td.object error: ->
      env._assertVlan(process, console, 'vlan')
      td.verify process.exit(1), times: 1
      td.verify console.error('Error: Environment variable \'vlan\' should be a number between 1 and 4095 or not set at all'), times: 1
    describe 'should not accept', ->
      negativeVlanTest '0'
      negativeVlanTest '4096'
      negativeVlanTest 'bogus'

    describe 'behavior when environment variable is not set', ->
      it 'should simply return when vlan is not set', ->
        assert.equal env.assertVlan('notsetvlan'), undefined
