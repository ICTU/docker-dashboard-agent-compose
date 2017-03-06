require("../../../target/goog/bootstrap/nodejs") unless global.goog
require("../../../target/cljs/core") unless global.cljs
require('../../../target/compose/compose') unless global.compose
goog.require("compose.compose")

assert  = require 'assert'
_       = require 'lodash'

describe 'Cljs Compose', ->
  describe 'mapv2', ->

    it 'should not alter the compose object when it is already version 2.1', ->
      compose =
        version: '2.1'
        services: www: {}
      assert.deepEqual global.compose.compose.mapv2(compose), compose

    it 'should update the compose version to 2.1 when version is 2.0', ->
      compose =
        version: '2.0'
        services: www: {}
      assert.deepEqual global.compose.compose.mapv2(compose), _.extend compose, version: '2.1'

    it 'should update the compose version to 2.1 when version is 1.0', ->
      compose =
        version: '1.0'
        services: www: {}
      assert.deepEqual global.compose.compose.mapv2(compose), _.extend compose, version: '2.1'

    it 'should update the compose version to 2.1 when version is absent', ->
      compose = www: {}
      expected = version: '2.1', services: www: {}
      assert.deepEqual global.compose.compose.mapv2(compose), expected
