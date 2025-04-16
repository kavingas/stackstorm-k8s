#!/bin/bash

# Load env vars from .env
set -o allexport
source .env
set +o allexport

cd charts

rm -f mongodb-10.0.1.tgz
tar czf mongodb-10.0.1.tgz mongodb

rm -f rabbitmq-8.0.2.tgz
tar czf rabbitmq-8.0.2.tgz rabbitmq

rm -f redis-12.3.2.tgz
tar czf redis-12.3.2.tgz redis

cd ..

helm package .

# Use curl with env vars
curl -u"$ARTIFACTORY_USERNAME:$ARTIFACTORY_API_KEY" \
  -T stackstorm-ha-1.1.0.tgz \
  "https://artifactory-uw2.adobeitc.com/artifactory/helm-stackstorm-release/stackstorm-ha-1.1.0.tgz"
