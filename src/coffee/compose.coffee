_         = require 'lodash'
path      = require 'path'
resolvep  = require 'resolve-path'

composeLib = require './compose/lib.coffee'

module.exports = (config) ->
  vlan = if config.vlan then " @#{config.vlan}" else  ''
  networkValue = "#{config.host_if} -i eth0 @CONTAINER_NAME@ 0/0#{vlan}"

  augmentCompose: (instance, options, doc) ->
    addNetworkContainer = (serviceName, service) ->
      if service.labels['bigboat.service.type'] in ['service', 'oneoff']
        labels = _.extend {}, service.labels,
          'bigboat.service.type': 'net'
        subDomain = "#{instance}.#{config.domain}.#{config.tld}"
        netcontainer =
          image: 'ictu/pipes'
          environment: eth0_pipework_cmd: networkValue
          hostname: "#{serviceName}.#{subDomain}"
          dns_search: subDomain
          network_mode: 'none'
          cap_add: ["NET_ADMIN"]
          labels: labels
          stop_signal: 'SIGKILL'
          healthcheck: config.net_container.healthcheck

        if service.container_name
          netcontainer['container_name'] = "#{service.container_name}-net"

        doc.services["bb-net-#{serviceName}"] = netcontainer
        # remove the hostname if set in the service, the hostname is set from
        # the network container
        delete service.hostname
        delete service.net
        service.network_mode = "service:bb-net-#{serviceName}"

        depends_on = composeLib.transformDependsOnToObject(service.depends_on) or {}
        depends_on["bb-net-#{serviceName}"] = condition: 'service_healthy'
        service.depends_on = depends_on

      else service.network_mode = "service:bb-net-#{service.labels['bigboat.service.name']}"

    resolvePath = (root, path) ->
      path = path[1...] if path[0] is '/'
      resolvep root, path

    addVolumeMapping = (serviceName, service) ->
      bucketPath = path.join config.dataDir, config.domain, options.storageBucket if options.storageBucket
      service.volumes = service.volumes?.map (v) ->
        vsplit = v.split ':'
        try
          if vsplit.length is 2
            if vsplit[1] in ['rw', 'ro']
              v
            else if bucketPath
              "#{resolvePath bucketPath, vsplit[0]}:#{vsplit[1]}"
            else vsplit[1]
          else if vsplit.length is 3
            if bucketPath
              "#{resolvePath bucketPath, vsplit[0]}:#{vsplit[1]}:#{vsplit[2]}"
            else "#{vsplit[1]}"
          else v
        catch e
          console.error "Error while mapping volumes. Root: #{bucketPath}, path: #{v}", e
          null
      delete service.volumes unless service.volumes
      service.volumes = service.volumes.filter((s) -> s) if service.volumes

    restrictCompose = (serviceName, service) ->
      delete service.cap_add
      delete service.cap_drop
      delete service.cgroup_parent
      delete service.devices
      delete service.dns
      delete service.dns_search
      delete service.networks
      delete service.ports
      delete service.privileged
      delete service.tmpfs

    migrateLinksToDependsOn = (serviceName, service) ->
      if service.links
        links = (service.links.map (l) -> l.split(':')[0])
        deps = composeLib.transformDependsOnToObject(service.depends_on) or {}
        for l in links
          deps[l] = condition: 'service_started' unless deps[l]
        service.depends_on = deps
        delete service.links

    migrateLogging = (serviceName, service) ->
       # if log_driver is set, that means we are in a compose v1 and logging is not present, no need to merge
      if service.log_driver
        service.logging =
          driver: service.log_driver
        service.logging.options = service.log_opt if service.log_opt
        delete service.log_driver
        delete service.log_opt

    addExtraLabels = (serviceName, service) ->
      service.labels = _.extend {}, service.labels,
        'bigboat.domain': config.domain
        'bigboat.tld': config.tld

    addDockerMapping = (serviceName, service) ->
      if service.labels['bigboat.container.map_docker'] is 'true'
        service.volumes = [] unless service.volumes
        service.volumes.push '/var/run/docker.sock:/var/run/docker.sock'

    for serviceName, service of doc.services
      migrateLinksToDependsOn serviceName, service
      addExtraLabels serviceName, service
      addNetworkContainer serviceName, service
      addVolumeMapping serviceName, service
      addDockerMapping serviceName, service
      migrateLogging serviceName, service
      restrictCompose serviceName, service

    delete doc.volumes
    delete doc.networks


    doc
