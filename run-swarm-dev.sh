#!/bin/bash

DOCKER_HOST=tcp://10.19.88.49:2375 \
AUTH_TOKEN=innovation \
HTTP_PORT=8080 \
MQTT_URL=mqtt://localhost \
MQTT_USER=user \
MQTT_PASS=pass \
DOMAIN=swarm \
TLD=ictu \
SCRIPT_BASE_DIR=/local/data/scripts \
DATA_DIR=/local/data \
NETWORK_NAME=zzz-bigboat-apps-3096 \
nodemon index.coffee


