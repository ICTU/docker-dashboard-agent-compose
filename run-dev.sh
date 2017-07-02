#!/bin/bash

# DOCKER_HOST=tcp://10.19.88.248:2375 \
AUTH_TOKEN=test \
HTTP_PORT=8080 \
MQTT_URL=mqtt://mqtt.gantcho-test.infra.ictu \
MQTT_USER=user \
MQTT_PASS=pass \
DOMAIN=infra \
TLD=ictu \
SCRIPT_BASE_DIR=/local/data/scripts \
DATA_DIR=/local/data \
REMOTEFS_URL=http://localhost:8000 \
NETWORK_SCAN_INTERVAL=60000 \
NETWORK_SCAN_ENABLED=false \
NETWORK_NAME=apps \
nodemon index.coffee
