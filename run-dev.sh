#!/bin/bash

docker run --rm -v $PWD:/build -w /build clojure:lein-2.7.1-alpine lein cljsbuild once nodejs

DOCKER_HOST=tcp://10.19.88.248:2375 \
AUTH_TOKEN=innovation \
HTTP_PORT=8080 \
VLAN=3080 \
MQTT_URL=mqtt://localhost \
MQTT_USER=user \
MQTT_PASS=pass \
DOMAIN=infra \
TLD=ictu \
SCRIPT_BASE_DIR=/local/data/scripts \
DATA_DIR=/local/data \
HOST_IF=eth1 \
REMOTEFS_URL=http://10.19.88.248:8000 \
NETWORK_HEALTHCHECK_TEST_INTERFACE=eth0 \
NETWORK_HEALTHCHECK_TEST_IP_PREFIX=10.25 \
nodemon index.coffee
