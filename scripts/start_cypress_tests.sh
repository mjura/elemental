#!/bin/bash

set -evx

# Needed to install Cypress plugins
npm install

# Start Cypress tests with docker
docker run -v $PWD:/e2e -w /e2e                            \
    -e RANCHER_USER=$RANCHER_USER                          \
    -e RANCHER_PASSWORD=$RANCHER_PASSWORD                  \
    -e RANCHER_URL=$RANCHER_URL                            \
    -e K8S_VERSION_TO_PROVISION=$K8S_VERSION_TO_PROVISION  \
    --add-host host.docker.internal:host-gateway           \
    $CYPRESS_DOCKER                                        \
    -s /e2e/$SPEC
