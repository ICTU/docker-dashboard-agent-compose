#!/bin/bash

AUTH_TOKEN=infra \
HTTP_PORT=8080 \
VLAN=3080 \
MQTT_URL=mqtt://localhost \
DOMAIN=infra \
TLD=ictu \
SCRIPT_BASE_DIR=/local/data/scripts \
DATA_DIR=/local/data \
HOST_IF=ens192 \
nodemon index.coffee
