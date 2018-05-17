# Architecture

## Purpose
The purpose of this service is to translate requests for starting and stopping of instances to the appropriate [Docker Compose](https://docs.docker.com/compose/) commands.
The second goal is to add aditional functionality on top of Docker Compose, like:

- Storage buckets
- Networking
- Security

![Overview](./overview.mmd.png)

## Features

### Storage buckets
The agent automatically chroots volume mappings of a Docker Compose file to a project and bucket specific base folder. Both relative and absolute paths will be chrooted.

The example demonstrates the rewrite process. In this example the base folder is `/shared/data/my_project` and the bucket name is `my-website`.

```
version: 2.0
services:
  www:
    image: nginx
    volumes:
      - ./website:/usr/share/nginx/html

# will rewritten as:

version: 2.0
services:
  www:
    image: nginx
    volumes:
      - /shared/data/my_project/my-website/website:/usr/share/nginx/html
```

### Networking
The agent makes all containers first-class citizens of a network. It does this by providing a network sidecar container. This container is responsible for acquiring an IP-address. See [ictu/pipes:2](https://github.com/ICTU/pipes)

### Security
The agent limits the use of certain Docker Compose features in order to secure the environment in which the instance is deployed.

The following capabilities are removed:

- cap_add
- cap_drop
- cgroup_parent
- devices
- dns
- dns_search
- ports
- privileged
- tmpfs

## HTTP API

## MQTT