_         = require 'lodash'
path      = require 'path'
resolvep  = require 'resolve-path'

composeLib = require './compose/lib.coffee'

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

  _addNetConfig: addNetConfig = (serviceName, service, instance, doc) ->
    subDomain = "#{instance}.#{config.domain}.#{config.tld}"
    hostname = "#{serviceName}.#{subDomain}"
    # drop all networks, maybe we should keep them?
    service.networks = default: aliases: [hostname]
    service.dns_search = subDomain
    service.hostname = hostname unless service.hostname
    delete service.network_mode

  _setDefaultNetwork: setDefaultNetwork = (doc) ->
    # drop all networks, maybe we should keep them?
    doc.networks = default: external: name: config.network.name

  augmentCompose: (instance, options, doc) ->
    setDefaultNetwork doc
    for serviceName, service of doc.services
      migrateLinksToDependsOn serviceName, service
      addExtraLabels serviceName, service
      addNetConfig serviceName, service, instance, doc
      addVolumeMapping serviceName, service, options
      addLocaltimeMapping serviceName, service
      addDockerMapping serviceName, service
      restrictCompose serviceName, service

    doc.version = '2.1'

    delete doc.volumes
    doc
