assert  = require 'assert'
td      = require 'testdouble'

spawn = null
transformDependsOnToObject = null
runCmd = null

describe 'Compose lib', ->

  afterEach -> td.reset()

  beforeEach ->
    spawn = td.replace('child_process').spawn
    lib = require '../../../src/coffee/compose/lib.coffee'
    transformDependsOnToObject = lib.transformDependsOnToObject
    runCmd = lib.runCmd

  describe 'transformDependsOnToObject', ->

    it 'should return null when the argument is falsy', ->
      assert.deepEqual transformDependsOnToObject(null), null
      assert.deepEqual transformDependsOnToObject(false), null

    it 'should return the unchanged argument when the argument is an object', ->
      depends_on =
        www: condition: 'service_healthy'
        db: condition: 'service_started'
        someOther: key: 'prop'
      assert.deepEqual transformDependsOnToObject(depends_on), depends_on

    it 'should transform a list of service names to a depends_on object with a default condition property', ->
      depends_on_list = ['www', 'db', 'someOther']
      assert.deepEqual transformDependsOnToObject(depends_on_list),
        www: condition: 'service_started'
        db: condition: 'service_started'
        someOther: condition: 'service_started'

  describe 'runCmd', ->
    it 'should log an error when the command did not run sucessfully', ->
      td.when(spawn 'myCmd', {myArgs: 1}, td.matchers.anything()).thenReturn {error: 'some error'}
      _console = td.object ['error']
      runCmd 'myCmd', {myArgs: 1}, {}, null, null, _console
      td.verify _console.error "Error, unable to execute", 'myCmd', {myArgs: 1}, 'some error'

    it 'should log and call appropriate callbacks on successful completion', ->
      spawned =
        stdout: td.object ['on']
        stderr: td.object ['on']
        on: td.function()
      _console = td.object ['log']
      callbacks =
        stdout: 1
        stderr: 2
      td.when(spawn 'myCmd', {myArgs: 1}, td.matchers.anything()).thenReturn spawned
      runCmd 'myCmd', {myArgs: 1}, {}, callbacks, 'exitCb', _console
      td.verify _console.log 'success', 'myCmd', {myArgs: 1}
      td.verify spawned.stdout.on 'data', 1
      td.verify spawned.stderr.on 'data', 2
      td.verify spawned.on 'close', 'exitCb'
