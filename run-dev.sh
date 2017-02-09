#!/bin/bash

docker run -v $PWD:/build -w /build clojure:lein-2.7.1-alpine lein cljsbuild once nodejs

DOCKER_HOST=tcp://10.19.88.248:2375 \
AUTH_TOKEN=infra \
HTTP_PORT=8080 \
VLAN=3080 \
MQTT_URL=mqtt://localhost \
DOMAIN=infra \
TLD=ictu \
SCRIPT_BASE_DIR=/local/data/scripts \
DATA_DIR=/local/data \
HOST_IF=ens192 \
REMOTEFS_URL=http://10.19.88.248:8000 \
nodemon index.coffee
