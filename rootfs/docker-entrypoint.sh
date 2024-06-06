#!/bin/bash
# Copyright (c) Swarm Library Maintainers.
# SPDX-License-Identifier: MIT

set -e

# Prometheus configuration file.
PROMETHEUS_CONFIG_DIR="/prometheus/config"
PROMETHEUS_CONFIG_FILE=${PROMETHEUS_CONFIG_FILE:-"/etc/prometheus/prometheus.yml"}

# Directory containing the scrape configuration files.
PROMETHEUS_SCRAPE_CONFIG_DIR="/prometheus/scrape_configs"

# Prometheus data directory.
PROMETHEUS_TSDB_PATH="/prometheus/data"

# Create the directory for the configuration parts.
mkdir -p $(dirname ${PROMETHEUS_CONFIG_FILE})
mkdir -p ${PROMETHEUS_CONFIG_DIR}

# Generate the global configuration file.
PROMETHEUS_SCRAPE_INTERVAL=${PROMETHEUS_SCRAPE_INTERVAL:-"1m"}
PROMETHEUS_SCRAPE_TIMEOUT=${PROMETHEUS_SCRAPE_TIMEOUT:-"10s"}
PROMETHEUS_EVALUATION_INTERVAL=${PROMETHEUS_EVALUATION_INTERVAL:-"1m"}

echo "==> Generating the global configuration file..."
cat <<EOF >${PROMETHEUS_CONFIG_DIR}/00-global.yml
global:
  scrape_interval: ${PROMETHEUS_SCRAPE_INTERVAL} # Set the scrape interval to every ${PROMETHEUS_SCRAPE_INTERVAL}. Default is every 1 minute.
  scrape_timeout: ${PROMETHEUS_SCRAPE_TIMEOUT} # scrape_timeout is set to the ${PROMETHEUS_SCRAPE_TIMEOUT}. The default is 10s.
  evaluation_interval: ${PROMETHEUS_EVALUATION_INTERVAL} # Evaluate rules every ${PROMETHEUS_EVALUATION_INTERVAL}. The default is every 1 minute.

scrape_config_files:
  - "${PROMETHEUS_SCRAPE_CONFIG_DIR}/*"
EOF

# Generate the alertmanager configuration file.
ALERTING_CONFIG_FILE=${ALERTING_CONFIG_FILE:-"${PROMETHEUS_CONFIG_DIR}/10-alerting.yml"}
if [ ! -f "${ALERTING_CONFIG_FILE}" ]; then
    /utils/generate-alerting-config "${ALERTING_CONFIG_FILE}"
fi

# Generate the configuration file by concatenating all the parts.
echo "# Generated by /docker-entrypoint.sh" > "${PROMETHEUS_CONFIG_FILE}"
for partfile in ${PROMETHEUS_CONFIG_DIR}/*; do
    echo "" >> "${PROMETHEUS_CONFIG_FILE}"
    echo "# Source: ${partfile}" >> "${PROMETHEUS_CONFIG_FILE}"
    cat "$partfile" >> "${PROMETHEUS_CONFIG_FILE}"
done

# If the user is trying to run Prometheus directly with some arguments, then
# pass them to Prometheus.
if [ "${1:0:1}" = '-' ]; then
    set -- prometheus "$@"
fi

# If the user is trying to run Prometheus directly with out any arguments, then
# pass the configuration file as the first argument.
if [ "$1" = "" ]; then
    set -- prometheus \
        --config.file="${PROMETHEUS_CONFIG_FILE}" \
        --storage.tsdb.path="${PROMETHEUS_TSDB_PATH}" \
        --web.console.libraries=/usr/share/prometheus/console_libraries \
        --web.console.templates=/usr/share/prometheus/consoles
fi

set -x
exec "$@"
