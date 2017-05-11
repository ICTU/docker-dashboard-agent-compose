assert  = require 'assert'
compose = require '../../src/coffee/compose.coffee'

standardCfg =
  net_container:
    image: 'ictu/pipes:1'
    pipeworksCmd: 'eth12 -i eth0 @CONTAINER_NAME@ dhclient @1234'

describe 'Compose', ->
  describe 'augmentCompose', ->
    it 'should set the compose version to 2.1', ->
      doc = version: '1.0'
      compose(standardCfg).augmentCompose '', {}, doc
      assert.equal doc.version, '2.1'
    it 'should delete the volumes section from the compose file', ->
      doc = volumes: {}
      assert.equal doc.volumes?, true
      compose(standardCfg).augmentCompose '', {}, doc
      assert.equal doc.volumes?, false
    it 'should delete the networks section from the compose file', ->
      doc = networks: {}
      assert.equal doc.networks?, true
      compose(standardCfg).augmentCompose '', {}, doc
      assert.equal doc.networks?, false

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
      compose(standardCfg)._restrictCompose '', service
      assert.deepEqual service, this_is_not_dropped: 1

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
      assert.deepEqual service, depends_on:
        db: {condition: 'service_started'}
        some_other_service: {condition: 'service_started'}
    it 'should merge all links with all depends_on (as object) services', ->
      service =
        links: ['db']
        depends_on: some_other_service: condition: 'some_condition'
      compose(standardCfg)._migrateLinksToDependsOn '', service
      assert.deepEqual service, depends_on:
        db: {condition: 'service_started'}
        some_other_service: {condition: 'some_condition'}
    it 'should prefer a dependency from depends_on over one from links if they are the same', ->
      service =
        links: ['db']
        depends_on: db: condition: 'my_specific_condition'
      compose(standardCfg)._migrateLinksToDependsOn '', service
      assert.deepEqual service, depends_on:
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

  describe '_addDockerMapping', ->
    it 'should add a volume mapping to the docker socket only when the value of bigboat.container.map_docker label is true', ->
      service =
        volumes: ['existing_volume']
        labels: 'bigboat.container.map_docker': 'true'
      compose(standardCfg)._addDockerMapping '', service
      assert.deepEqual service, Object.assign {volumes: ['existing_volume', '/var/run/docker.sock:/var/run/docker.sock']}, service
    it 'should not do anything when the label is missing', ->
      service = volumes: ['existing_volume']
      compose(standardCfg)._addDockerMapping '', service
      assert.deepEqual service, Object.assign {volumes: ['existing_volume']}, service

  describe '_addExtraLabels', ->
    it 'should add bigboat domain and tld labels based on configuration', ->
      service = labels: existing_label: 'value'
      compose(Object.assign {}, standardCfg, {domain:'google', tld:'com'})._addExtraLabels '', service
      assert.deepEqual service, labels:
        existing_label: 'value'
        'bigboat.domain': 'google'
        'bigboat.tld': 'com'

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

  describe '_addNetworkContainer', ->
    invokeTestSubject = (service, cfgNetContainer) ->
      doc = services: {}
      config = Object.assign {}, standardCfg,
        domain: 'google'
        tld: 'com'
        net_container: Object.assign {}, standardCfg.net_container, cfgNetContainer
      compose(config)._addNetworkContainer 'service1', service, 'instance2', doc
      doc
    containerTest = (serviceType) ->
      service =
        labels:
          'bigboat.service.type': serviceType
      doc = invokeTestSubject service
      assert.equal service.network_mode, 'service:bb-net-service1'
      assert.deepEqual service.depends_on, 'bb-net-service1': condition: 'service_started'
      assert.deepEqual doc.services['bb-net-service1'],
        image: 'ictu/pipes:1'
        environment: eth0_pipework_cmd: "eth12 -i eth0 @CONTAINER_NAME@ dhclient @1234"
        hostname: 'service1.instance2.google.com'
        dns_search: 'instance2.google.com'
        network_mode: 'none'
        cap_add: ['NET_ADMIN']
        labels: 'bigboat.service.type': 'net'
        stop_signal: 'SIGKILL'
    it 'should should add a network container for compose service of type \'service\'', ->
      containerTest 'service'
    it 'should should add a network container for compose service of type \'oneoff\'', ->
      containerTest 'oneoff'
    it 'should inherit all labels from the service container, except the bigboat.service.type label', ->
      service =
        labels:
          'bigboat.service.type': 'service'
          some_other_label: 'value'
      doc  = invokeTestSubject service
      assert.deepEqual doc.services['bb-net-service1'].labels,
        'bigboat.service.type': 'net'
        some_other_label: 'value'

    it 'should set the netcontainer healthcheck when configured', ->
      service =
        labels:
          'bigboat.service.type': 'service'
      doc = invokeTestSubject service, healthcheck: 'some-check'
      assert.equal doc.services['bb-net-service1'].healthcheck, 'some-check'
      assert.deepEqual service.depends_on, 'bb-net-service1': condition: 'service_healthy'

    it 'should use the container_name from the service, if any, to populate the netcontainer name', ->
      service =
        labels:
          'bigboat.service.type': 'oneoff'
        container_name: 'some-name'
      doc = invokeTestSubject service
      assert.equal doc.services['bb-net-service1'].container_name, 'some-name-net'

    it 'should simply change the network_mode to use an existing netcontainer when the service type is anything other than service or oneoff', ->
      service =
        labels:
          'bigboat.service.type': 'something-else'
          'bigboat.service.name': 'myservice'
      doc = invokeTestSubject service
      assert.equal service.network_mode, 'service:bb-net-myservice'
      assert.deepEqual doc, services: {}

    it 'should use the provided network image version', ->
      service = labels: 'bigboat.service.type': 'service'
      doc = invokeTestSubject service, image: 'ictu/pipes:2'
      assert.equal doc.services['bb-net-service1'].image, 'ictu/pipes:2'
