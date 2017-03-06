assert  = require 'assert'
{transformDependsOnToObject}     = require './lib.coffee'

describe 'Compose lib', ->
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
