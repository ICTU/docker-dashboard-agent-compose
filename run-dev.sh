#!/bin/bash

DOCKER_HOST=unix:///var/run/docker.sock \
AUTH_TOKEN=innovation \
HTTP_PORT=8080 \
MQTT_URL=mqtt://localhost \
MQTT_USER=user \
MQTT_PASS=pass \
DOMAIN=acc \
TLD=ictu \
SCRIPT_BASE_DIR=/local/data/scripts \
DATA_DIR=/tmp \
REMOTEFS_URL=http://10.19.88.248:8000 \
NETWORK_NAME=bigboat-apps-3080 \
NETWORK_PARENT_NIC=wlp3s0 \
NETWORK_SCAN_INTERVAL=60000 \
NETWORK_SCAN_ENABLED=false \
NETWORK_HEALTHCHECK_INTERVAL=2s \
NETWORK_HEALTHCHECK_TIMEOUT=35s \
NETWORK_HEALTHCHECK_RETRIES=10 \
NETWORK_HEALTHCHECK_TEST="if [ ! -f /tmp/healthcheck ]; then ifconfig eth0 | grep 'inet addr:'; [ \$\$? -eq 0 ] && touch /tmp/healthcheck; else sleep 30; ifconfig eth0 | grep 'inet addr:'; fi" \
NETWORK_HEALTHCHECK_TEST_INTERFACE=eth0 \
NETWORK_HEALTHCHECK_TEST_IP_PREFIX=10.25 \
nodemon index.coffee
