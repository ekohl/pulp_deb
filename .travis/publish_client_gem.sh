#!/bin/bash

# WARNING: DO NOT EDIT!
#
# This file was generated by plugin_template, and is managed by it. Please use
# './plugin-template --travis pulp_deb' to update this file.
#
# For more info visit https://github.com/pulp/plugin_template

set -euv

echo "---
:rubygems_api_key: $RUBYGEMS_API_KEY" > ~/.gem/credentials
sudo chmod 600 ~/.gem/credentials

cd $TRAVIS_BUILD_DIR
export REPORTED_VERSION=$(http pulp/pulp/api/v3/status/ | jq --arg plugin pulp_deb -r '.versions[] | select(.component == $plugin) | .version')
export DESCRIPTION="$(git describe --all --exact-match `git rev-parse HEAD`)"
if [[ $DESCRIPTION == 'tags/'$REPORTED_VERSION ]]; then
  export VERSION=${REPORTED_VERSION}
else
  # Daily publishing of development version (ends in ".dev" reported as ".dev0")
  if [ "${REPORTED_VERSION%.dev*}" == "${REPORTED_VERSION}" ]; then
    echo "Refusing to publish bindings. $REPORTED_VERSION does not contain 'dev'."
    exit 1
  fi
  export EPOCH="$(date +%s)"
  export VERSION=${REPORTED_VERSION}${EPOCH}
fi

export response=$(curl --write-out %{http_code} --silent --output /dev/null https://rubygems.org/gems/pulp_deb_client/versions/$VERSION)

if [ "$response" == "200" ];
then
  exit
fi

cd "${TRAVIS_BUILD_DIR}"/../pulp-openapi-generator

./generate.sh pulp_deb ruby $VERSION
cd pulp_deb-client
gem build pulp_deb_client
GEM_FILE="$(ls pulp_deb_client-*)"
gem push ${GEM_FILE}
