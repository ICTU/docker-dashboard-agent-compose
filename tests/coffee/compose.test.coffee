assert  = require 'assert'
compose = require '../../src/coffee/compose.coffee'

standardCfg =
  net_container:
    image: 'ictu/pipes:2'
  network:
    name: 'apps'

describe 'Compose', ->
  describe 'augmentCompose', ->
    it 'should set the compose version to 3.3', ->
      doc = version: '1.0'
      compose(standardCfg).augmentCompose '', {}, doc
      assert.equal doc.version, '3.3'
    it 'should delete the volumes section from the compose file', ->
      doc = volumes: {}
      assert.equal doc.volumes?, true
      compose(standardCfg).augmentCompose '', {}, doc
      assert.equal doc.volumes?, false
    it 'should set the default network in the compose file', ->
      doc = networks: {}
      assert.equal doc.networks?, true
      compose(standardCfg).augmentCompose '', {}, doc
      assert.deepEqual doc.networks, public: external: name: 'apps'

  describe '_restrictCompose', ->
    it 'should drop certain service capabilities', ->
      service =
        cap_add: 1
        cap_drop: 1
        cgroup_parent: 1
        devices: 1
        dns: 1
        dns_search: 1
        ports: 1
        privileged: 1
        tmpfs: 1
        this_is_not_dropped: 1
      compose(standardCfg)._restrictCompose '', service
      assert.deepEqual service, this_is_not_dropped: 1

  describe '_moveLinksToNetContainer', ->
    it 'should leave the document untouched when there are no links', ->
      doc = services: www: image: 'someimage'
      compose(standardCfg)._moveLinksToNetContainer 'www', doc.services.www, doc
      assert.deepEqual doc, services: www: image: 'someimage'
    it 'should move all links to links between net containers', ->
      doc =
        services:
          'bb-net-myservice': {}
          myservice:
            links: ['db', "service:alias"]
      compose(standardCfg)._moveLinksToNetContainer 'myservice', doc.services.myservice, doc
      assert.deepEqual doc.services['bb-net-myservice'],
        links: [
          'bb-net-db:db'
          'bb-net-service:alias'
        ]

  describe '_migrateLinksToDependsOn', ->
    it 'should leave the document untouched when there are no links', ->
      doc = services: www: image: 'someimage'
      compose(standardCfg)._migrateLinksToDependsOn '', doc
      assert.deepEqual doc, services: www: image: 'someimage'
    it 'should merge all links with all depends_on (as list) services', ->
      service =
        links: ['db']
        depends_on: ['some_other_service']
      compose(standardCfg)._migrateLinksToDependsOn '', service
      assert.deepEqual service,
        depends_on:
          db: {condition: 'service_started'}
          some_other_service: {condition: 'service_started'}
    it 'should merge all links with all depends_on (as object) services', ->
      service =
        links: ['db']
        depends_on: some_other_service: condition: 'some_condition'
      compose(standardCfg)._migrateLinksToDependsOn '', service
      assert.deepEqual service,
        depends_on:
          db: {condition: 'service_started'}
          some_other_service: {condition: 'some_condition'}
    it 'should prefer a dependency from depends_on over one from links if they are the same', ->
      service =
        links: ['db']
        depends_on: db: condition: 'my_specific_condition'
      compose(standardCfg)._migrateLinksToDependsOn '', service
      assert.deepEqual service,
        depends_on:
          db: {condition: 'my_specific_condition'}

  describe '_resolvePath', ->
    it 'should resolve a path relative to a given root', ->
      c = compose(standardCfg)
      assert.equal c._resolvePath('/some/root', '/my/rel/path'), '/some/root/my/rel/path'
      assert.equal c._resolvePath('/some/root/', '/my/rel/path'), '/some/root/my/rel/path'
      assert.equal c._resolvePath('/some/root', 'my/rel/path'), '/some/root/my/rel/path'
      assert.equal c._resolvePath('/some/root', './my/rel/path'), '/some/root/my/rel/path'
      assert.equal c._resolvePath('/some/root', '/other/../my/rel/path'), '/some/root/my/rel/path'
      assert.equal c._resolvePath('/some/root/', '/some/root/../../one/level/up'), '/some/root/one/level/up'
    it 'should throw an error when a relative path resolves outside of the given root', ->
      assert.throws ->
        compose(standardCfg)._resolvePath '/some/root/', '../one/level/up'
      , Error
      assert.throws ->
        compose(standardCfg)._resolvePath '/some/root/', '/../../.././one/level/up'
      , Error

  describe '_addExtraLabels', ->
    it 'should add bigboat domain and tld labels based on configuration', ->
      service = labels: existing_label: 'value'
      labels =
        existing_label: 'value'
        'bigboat.domain': 'google'
        'bigboat.tld': 'com'
      compose(Object.assign {}, standardCfg, {domain:'google', tld:'com'})._addExtraLabels '', service
      assert.deepEqual service,
        labels: labels
        deploy: labels: labels

  describe '_addVolumeMapping', ->
    volumeTest = (inputVolume, expectedVolume, opts = {storageBucket: 'bucket1'}) ->
      c = compose Object.assign {}, standardCfg, dataDir: '/local/data/', domain: 'google'
      service = volumes: [inputVolume]
      c._addVolumeMapping '', service, opts
      assert.deepEqual service, volumes: [expectedVolume]
    it 'should root a volume to a base path (data bucket)', ->
      volumeTest '/my/mapping:/internal/volume', '/local/data/google/bucket1/my/mapping:/internal/volume'
    it 'should remove a volume\'s mapping when no storage bucket is given (no persistence)', ->
      volumeTest '/my/mapping:/internal/volume', '/internal/volume', {}
    it 'should leave a :rw postfix intact', ->
      volumeTest '/my/mapping:/internal/volume:rw', '/local/data/google/bucket1/my/mapping:/internal/volume:rw'
    it 'should leave a :ro postfix intact', ->
      volumeTest '/my/mapping:/internal/volume:ro', '/local/data/google/bucket1/my/mapping:/internal/volume:ro'
    it 'should remove the postfix when no storage bucket is given (compose bug)', ->
      volumeTest '/my/mapping:/internal/volume:rw', '/internal/volume', {}
    it 'should not do anything to an unmapped volume', ->
      volumeTest '/internal/volume', '/internal/volume'
    it 'should not do anything to an unmapped volume when no data bucket is given', ->
      volumeTest '/internal/volume', '/internal/volume', {}
    it 'should remove a postfix (:ro) from an unmapped volume when no data bucket is given (compose bug)', ->
      volumeTest '/internal/volume:ro', '/internal/volume', {}
    it 'should remove a postfix (:rw) from an unmapped volume when no data bucket is given (compose bug)', ->
      volumeTest '/internal/volume:rw', '/internal/volume'
    it 'should discard a volume with a mapping that resolves outside of the bucket root', ->
      c = compose Object.assign {}, standardCfg, dataDir: '/local/data/', domain: 'google'
      service = volumes: ['../../my-malicious-volume/:/internal']
      c._addVolumeMapping '', service, storageBucket: 'bucket1'
      assert.deepEqual service, volumes: []
    it 'should not create invalid volume section', ->
      c = compose Object.assign {}, standardCfg, dataDir: '/local/data/', domain: 'google'
      service = image: 'something'
      c._addVolumeMapping '', service, {storageBucket: 'bucket1'}
      assert.deepEqual service, image: 'something'

  describe '_addLocaltimeMapping', ->
    localtimeTest = (service) ->
      c = compose Object.assign {}, standardCfg, dataDir: '/local/data/', domain: 'google'
      c._addLocaltimeMapping '', service
      expected = service.volumes or []
      expected.push '/etc/localtime:/etc/localtime:ro'
      assert.deepEqual service, volumes: expected
    it 'should add /etc/localtime volume mapping when there are no volumes', ->
      localtimeTest {}
    it 'should add /etc/localtime volume mapping when there are other volumes', ->
      localtimeTest volumes: ['volume1', '/mapped:/volume']
