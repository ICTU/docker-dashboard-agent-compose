#!/bin/bash

AUTH_TOKEN=infra \
HTTP_PORT=8080 \
VLAN=3080 \
MQTT_URL=mqtt://localhost \
DOMAIN=infra.ictu \
SCRIPT_BASE_DIR=/tmp/local/data/scripts \
nodemon index.coffee
