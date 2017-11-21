_ = require 'lodash'

module.exports = (instanceName, serviceName, node, ssh, config) ->
  subDomain = "#{instanceName}.#{config.domain}.#{config.tld}"
  hostname = "ssh.#{serviceName}.#{subDomain}"
  labels =
    'bigboat.instance.name': instanceName
    'bigboat.service.name': serviceName
    'bigboat.domain': config.domain
    'bigboat.tld': config.tld
    'bigboat.service.type': 'ssh'
    'bigboat.container.map_docker': 'true'
  config = (authMechanism, containerShell, authTuples) ->
    sshCompose =
      image: 'jeroenpeeters/docker-ssh:docker-filter'
      depends_on: [serviceName]
      labels: labels
      hostname: hostname
      networks: public: aliases: [hostname]
      deploy:
        mode: 'replicated'
        endpoint_mode: 'dnsrr'
        labels: labels
        resources: limits: memory: '128M'
        placement:
          constraints: [
            "node.hostname == #{node}"
          ]
      environment:
        FILTERS: JSON.stringify label: [
          "bigboat.instance.name=#{instanceName}"
          "bigboat.service.name=#{serviceName}"
          "bigboat.service.type=service"
        ]
        AUTH_MECHANISM: authMechanism
        HTTP_ENABLED: 'false'
        CONTAINER_SHELL: containerShell
      volumes: [
        '/var/run/docker.sock:/var/run/docker.sock'
        '/etc/localtime:/etc/localtime:ro'
      ]
    sshCompose.environment.AUTH_TUPLES = authTuples if authTuples
    sshCompose

  if typeof ssh is 'object'
    shell = ssh.shell or 'bash'
    auth = 'noAuth'
    authTuples = null
    if users = ssh.users
      auth = 'multiUser'
      authTuples = (_.toPairs(users).map ([key, val]) -> "#{key}:#{val}").join ';'
    config auth, shell, authTuples
  else
    config 'noAuth', 'bash'
