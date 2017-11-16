#!/bin/bash

DOCKER_HOST=tcp://10.25.96.22:2375 \
AUTH_TOKEN=innovation \
HTTP_PORT=8080 \
MQTT_URL=mqtt://localhost \
MQTT_USER=user \
MQTT_PASS=pass \
DOMAIN=swarm \
TLD=ictu \
SCRIPT_BASE_DIR=/local/data/scripts \
DATA_DIR=/local/data \
NETWORK_NAME=swarm-net \
nodemon index.coffee
