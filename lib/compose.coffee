_ = require 'lodash'

module.exports = (config) ->
  networkValue = "ens192 -i eth0 @CONTAINER_NAME@ dhclient @#{config.vlan}"
  networkEnv = 'eth0_pipework_cmd'

  appdef2compose: (instance, doc) ->
    delete doc.name
    delete doc.version
    delete doc.pic
    delete doc.description
    doc

  augmentCompose: (instance, doc) ->
    console.log 'doc', doc
    # addNetworkContainer = (serviceName, service) ->
    #   netcontainer =
    #     image: 'www.docker-registry.isd.ictu:5000/pipes:1'
    #
    #   doc["net-#{serviceName}"] = netcontainer

    addNetworking = (serviceName, service) ->
      subDomain = "#{instance}.#{config.domain}"
      service.net = 'none'
      service.dns_search = subDomain
      service.hostname = "#{serviceName}.#{subDomain}"
      if service.environment?.push
        service.environment.push "#{networkEnv}=#{networkValue}"
      else
        service.environment = _.merge {}, {"#{networkEnv}": networkValue}, service.environment

    for serviceName, service of doc
      addNetworking serviceName, service

    doc
