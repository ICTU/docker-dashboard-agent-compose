_         = require 'lodash'
path      = require 'path'
resolvep  = require 'resolve-path'
randomMac = require 'random-mac'

composeLib = require './compose/lib.coffee'

assembleHostname = (serviceName, instanceName, domain) ->
  hostname = "#{serviceName}.#{instanceName}.#{domain}".toLowerCase().replace(/_/g, '-')
  if hostname.length > 64
    if 64 + instanceName.length - hostname.length > 0
      hostname = "#{serviceName}.#{instanceName.substr(0, 64 + instanceName.length - hostname.length)}.#{domain}".toLowerCase().replace(/_/g, '-')
    else
      hostname = hostname.substring(0, 62) + '-x'
  return hostname

module.exports = (config) ->
  _restrictCompose: restrictCompose = (serviceName, service) ->
    delete service.cap_add
    delete service.cap_drop
    delete service.cgroup_parent
    delete service.devices
    delete service.dns
    delete service.dns_search
    delete service.ports
    delete service.privileged
    delete service.tmpfs

  _migrateLinksToDependsOn: migrateLinksToDependsOn = (serviceName, service) ->
    if service.links
      links = (service.links.map (l) -> l.split(':')[0])
      deps = composeLib.transformDependsOnToObject(service.depends_on) or {}
      for l in links
        deps[l] = condition: 'service_started' unless deps[l]
      service.depends_on = deps
      delete service.links

  _moveLinksToNetContainer: moveLinksToNetContainer = (serviceName, service, doc) ->
    if service.links
      links = for l in service.links
        [srv, alias] = l.split ':'
        alias = srv unless alias
        "bb-net-#{srv}:#{alias}"
      doc.services["bb-net-#{serviceName}"].links = links

  _resolvePath: resolvePath = (root, path) ->
    path = path[1...] if path[0] is '/'
    resolvep root, path

  _addDockerMapping: addDockerMapping = (serviceName, service) ->
    if service.labels?['bigboat.container.map_docker'] is 'true'
      service.volumes = [] unless service.volumes
      service.volumes.push '/var/run/docker.sock:/var/run/docker.sock'

  _addExtraLabels: addExtraLabels = (serviceName, service) ->
    service.labels = _.extend {}, service.labels,
      'bigboat.domain': config.domain
      'bigboat.tld': config.tld

  _addVolumeMapping: addVolumeMapping = (serviceName, service, options) ->
    bucketPath = path.join config.dataDir, config.domain, options.storageBucket if options.storageBucket
    service.volumes = service.volumes?.map (v) ->
      vsplit = v.split ':'
      try
        if vsplit.length is 2
          if vsplit[1] in ['rw', 'ro']
            vsplit[0]
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

  _addLocaltimeMapping: addLocaltimeMapping = (serviceName, service) ->
    service.volumes = [] unless service.volumes
    service.volumes.push "/etc/localtime:/etc/localtime:ro"

  _addNetworkContainer: addNetworkContainer = (serviceName, service, instance, doc) ->
    if service.labels['bigboat.service.type'] in ['service', 'oneoff']
      labels = _.extend {}, service.labels,
        'bigboat.service.type': 'net'
      subDomain = "#{instance}.#{config.domain}.#{config.tld}"
      netcontainer =
        image: config.net_container.image
        hostname: assembleHostname serviceName, instance, "#{config.domain}.#{config.tld}" #"#{serviceName}.#{subDomain}" #normalizeHostname "#{serviceName}.#{subDomain}"
        networks: appsnet: aliases: [serviceName]
        dns: ['10.25.55.2', '10.25.55.3']
        dns_search: subDomain
        dns_opt: ['ndots:1']
        cap_add: ["NET_ADMIN"]
        mac_address: randomMac()
        labels: labels
        stop_signal: 'SIGKILL'
        volumes: ['/var/run/dnsreg:/var/run/dnsreg']
        restart: 'unless-stopped'
      if config.net_container?.healthcheck
        netcontainer.healthcheck = config.net_container.healthcheck

      if service.container_name
        netcontainer['container_name'] = "#{service.container_name}-net"

      doc.services["bb-net-#{serviceName}"] = netcontainer
      # remove the hostname if set in the service, the hostname is set from
      # the network container
      delete service.hostname
      delete service.net
      service.network_mode = "service:bb-net-#{serviceName}"

      depends_on = composeLib.transformDependsOnToObject(service.depends_on) or {}
      depends_on["bb-net-#{serviceName}"] = if netcontainer.healthcheck
        condition: 'service_healthy'
      else
        condition: 'service_started'
      service.depends_on = depends_on

    else service.network_mode = "service:bb-net-#{service.labels['bigboat.service.name']}"

  _addDefaultNetwork: addDefaultNetwork = (doc) ->
    doc.networks = appsnet: external: name: config.network.name

  augmentCompose: (instance, options, doc) ->
    addDefaultNetwork doc
    for serviceName, service of doc.services
      addExtraLabels serviceName, service
      addNetworkContainer serviceName, service, instance, doc
      moveLinksToNetContainer serviceName, service, doc
      migrateLinksToDependsOn serviceName, service
      addVolumeMapping serviceName, service, options
      addLocaltimeMapping serviceName, service
      addDockerMapping serviceName, service
      restrictCompose serviceName, service

    doc.version = '2.2'
    delete doc.volumes
    doc
