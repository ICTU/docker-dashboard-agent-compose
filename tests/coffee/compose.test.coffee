assert  = require 'assert'
td      = require 'testdouble'
compose = require '../../src/coffee/compose.coffee'

describe 'Compose', ->
  describe '_restrictCompose', ->
    it 'should drop certain service capabilities', ->
      service =
        cap_add: 1
        cap_drop: 1
        cgroup_parent: 1
        devices: 1
        dns: 1
        dns_search: 1
        networks: 1
        ports: 1
        privileged: 1
        tmpfs: 1
        this_is_not_dropped: 1
      compose({})._restrictCompose '', service
      assert.deepEqual service, this_is_not_dropped: 1

  describe 'augmentCompose', ->
    it 'should set the compose version to 2.1', ->
      doc = version: '1.0'
      compose({}).augmentCompose '', {}, doc
      assert.equal doc.version, '2.1'
    it 'should delete the volumes section from the compose file', ->
      doc = volumes: {}
      assert.equal doc.volumes?, true
      compose({}).augmentCompose '', {}, doc
      assert.equal doc.volumes?, false
    it 'should delete the networks section from the compose file', ->
      doc = networks: {}
      assert.equal doc.networks?, true
      compose({}).augmentCompose '', {}, doc
      assert.equal doc.networks?, false
