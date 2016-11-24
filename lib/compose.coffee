_     = require 'lodash'
path  = require 'path'

module.exports = (config) ->
  networkValue = "eth1 -i eth0 @CONTAINER_NAME@ dhclient @#{config.vlan}"
  networkEnv = 'eth0_pipework_cmd'

  augmentCompose: (instance, options, doc) ->
    addNetworkContainer = (serviceName, service) ->
      if service.labels['bigboat.service.type'] is 'service'
        labels = _.extend {}, service.labels
        labels['bigboat.service.type'] = 'net'
        subDomain = "#{instance}.#{config.domain}.#{config.tld}"
        netcontainer =
          image: 'www.docker-registry.isd.ictu:5000/pipes:1'
          environment: eth0_pipework_cmd: networkValue
          hostname: "#{serviceName}.#{subDomain}"
          dns_search: subDomain
          net: 'none'
          labels: labels
          stop_signal: 'SIGKILL'
        if service.container_name
          netcontainer['container_name'] = "#{service.container_name}-net"

        doc["bb-net-#{serviceName}"] = netcontainer
        # remove the hostname if set in the service, the hostname is set from
        # the network container
        delete service.hostname
        service.net = "container:bb-net-#{serviceName}"
      else service.net = "container:bb-net-#{service.labels['bigboat.service.name']}"

    addVolumeMapping = (serviceName, service) ->
      bucketPath = path.join config.dataDir, config.domain, options.storageBucket if options.storageBucket
      service.volumes = service.volumes?.map (v) ->
        vsplit = v.split ':'
        if vsplit.length is 2
          if vsplit[1] in ['rw', 'ro']
            v
          else if bucketPath
            "#{path.join bucketPath, vsplit[0]}:#{vsplit[1]}"
          else vsplit[1]
        else if vsplit.length is 3
          if bucketPath
            "#{path.join bucketPath, vsplit[0]}:#{vsplit[1]}:#{vsplit[2]}"
          else "#{vsplit[1]}"
        else v
      delete service.volumes unless service.volumes

    addDockerMapping = (serviceName, service) ->
      if service.labels['bigboat.container.map_docker'] is 'true'
        service.volumes = [] unless service.volumes
        service.volumes.push '/var/run/docker.sock:/var/run/docker.sock'

    for serviceName, service of doc
      addNetworkContainer serviceName, service
      addVolumeMapping serviceName, service
      addDockerMapping serviceName, service
    doc
