#!/bin/bash

DOCKER_HOST=tcp://10.19.88.248:2375 \
AUTH_TOKEN=innovation \
HTTP_PORT=8080 \
PIPEWORKS_CMD="eth1 -i eth0 @CONTAINER_NAME@ dhclient @3080" \
MQTT_URL=mqtt://localhost \
MQTT_USER=user \
MQTT_PASS=pass \
DOMAIN=infra \
TLD=ictu \
SCRIPT_BASE_DIR=/local/data/scripts \
DATA_DIR=/local/data \
REMOTEFS_URL=http://10.19.88.248:8000 \
NETWORK_SCAN_INTERVAL=60000 \
NETWORK_SCAN_ENABLED=true \
NETWORK_HEALTHCHECK_INTERVAL=2s \
NETWORK_HEALTHCHECK_TIMEOUT=35s \
NETWORK_HEALTHCHECK_RETRIES=10 \
NETWORK_HEALTHCHECK_TEST="if [ ! -f /tmp/healthcheck ]; then ifconfig eth0 | grep 'inet addr:'; [ \$\$? -eq 0 ] && touch /tmp/healthcheck; else sleep 30; ifconfig eth0 | grep 'inet addr:'; fi" \
NETWORK_HEALTHCHECK_TEST_INTERFACE=eth0 \
NETWORK_HEALTHCHECK_TEST_IP_PREFIX=10.25 \
nodemon index.coffee
