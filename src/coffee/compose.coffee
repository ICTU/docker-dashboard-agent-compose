_         = require 'lodash'
path      = require 'path'
resolvep  = require 'resolve-path'
randomMac = require 'random-mac'

composeLib = require './compose/lib.coffee'

module.exports = (config) ->
  _restrictCompose: restrictCompose = (serviceName, service) ->
    delete service.mem_limit
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

  _addExtraLabels: addExtraLabels = (serviceName, service) ->
    labels = _.extend {}, service.labels,
      'bigboat.domain': config.domain
      'bigboat.tld': config.tld
    service.deploy = if service.deploy then service.deploy else {}
    service.labels = service.deploy.labels = labels

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

  _addNetworkSettings: addNetworkSettings = (serviceName, service, instance, doc) ->
    subDomain = "#{instance}.#{config.domain}.#{config.tld}"
    service.hostname = "#{serviceName}.#{subDomain}"
    service.networks = public: aliases: [service.hostname]
    delete service.network_mode

  _addDeploymentSettings: addDeploymentSettings = (service) ->
    defaultResources =
      limits:
        memory: '1G'
    resources = _.merge defaultResources, service.deploy?.resources
    service.deploy =
      mode: 'replicated'
      endpoint_mode: 'dnsrr'
      resources: resources


  _addDefaultNetwork: addDefaultNetwork = (doc) ->
    doc.networks = public: external: name: config.network.name

  augmentCompose: (instance, options, doc) ->
    delete doc.networks
    addDefaultNetwork doc
    for serviceName, service of doc.services
      addDeploymentSettings service
      addExtraLabels serviceName, service
      addNetworkSettings serviceName, service, instance, doc
      addVolumeMapping serviceName, service, options
      addLocaltimeMapping serviceName, service
      restrictCompose serviceName, service

      # service.deploy = placement: constraints: ['node.hostname == swarm02']

    doc.version = '3.3'
    delete doc.volumes
    console.log JSON.stringify doc, null, 2

    doc
