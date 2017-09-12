assert  = require 'assert'
td      = require 'testdouble'
_       = require 'lodash'

child_process = null
mkdirp = null
lib = null

config =
  compose: scriptBaseDir: "/my/scripts"
  domain: "my-domain"


describe 'Compose lib', ->
  describe 'transformDependsOnToObject', ->
    lib     = require '../../../src/coffee/compose/lib.coffee'

    it 'should return null when the argument is falsy', ->
      assert.deepEqual lib.transformDependsOnToObject(null), null
      assert.deepEqual lib.transformDependsOnToObject(false), null

    it 'should return the unchanged argument when the argument is an object', ->
      depends_on =
        www: condition: 'service_healthy'
        db: condition: 'service_started'
        someOther: key: 'prop'
      assert.deepEqual lib.transformDependsOnToObject(depends_on), depends_on

    it 'should transform a list of service names to a depends_on object with a default condition property', ->
      depends_on_list = ['www', 'db', 'someOther']
      assert.deepEqual lib.transformDependsOnToObject(depends_on_list),
        www: condition: 'service_started'
        db: condition: 'service_started'
        someOther: condition: 'service_started'

  describe 'saveScript', ->
    beforeEach ->
      mkdirp = td.replace 'mkdirp'
      lib = require '../../../src/coffee/compose/lib.coffee'
    afterEach -> td.reset()

    it 'should invoke mkdirp and fs.writeFile', ->
      td.when(mkdirp(td.matchers.anything(), td.matchers.anything())).thenCallback(null)
      lib.saveScript config, "my-file", "my-instance", "script data", td.function()
      td.verify mkdirp("/my/scripts/my-domain/my-instance", td.matchers.isA(Function))

    it 'should return script path', ->
      assert.equal lib.saveScript(config, "my-file", "my-instance", "nonce", td.function()), "/my/scripts/my-domain/my-instance/my-file"

  describe 'runCmd', ->
    beforeEach ->
      child_process = td.replace 'child_process'
      lib = require '../../../src/coffee/compose/lib.coffee'
    afterEach -> td.reset()

    it 'should spawn the command passed', ->
      spawned =
        error: null
        stdout: on: td.function()
        stderr: on: td.function()
        on: td.function()
        exitCode: 0
      td.when(child_process.spawn('test cmd', ['some', 'args'], td.matchers.isA(Object))).thenReturn spawned
      testEnv = env: _.extend {}, process.env, {var: 'val'}
      callbacks =
        stdout: td.function()
        stderr: td.function()
      lib.runCmd 'test cmd', ['some', 'args'], {var: 'val'}, callbacks
      td.verify child_process.spawn('test cmd', ['some', 'args'], testEnv)
      td.verify spawned.stdout.on('data', callbacks.stdout)
      td.verify spawned.stderr.on('data', callbacks.stderr)
      td.verify spawned.on('close', td.matchers.isA(Function))
