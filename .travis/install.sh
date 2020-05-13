#!/usr/bin/env bash

# WARNING: DO NOT EDIT!
#
# This file was generated by plugin_template, and is managed by it. Please use
# './plugin-template --travis pulp_deb' to update this file.
#
# For more info visit https://github.com/pulp/plugin_template

set -euv

if [ "$TEST" = "docs" ]; then
  pip install -r ../pulpcore/doc_requirements.txt
  pip install -r doc_requirements.txt
fi

pip install -r functest_requirements.txt

cd .travis

# Although the tag name is not used outside of this script, we might use it
# later. And it is nice to have a friendly identifier for it.
# So we use the branch preferably, but need to replace the "/" with the valid
# character "_" .
#
# Note that there are lots of other valid git branch name special characters
# that are invalid in image tag names. To try to convert them, this would be a
# starting point:
# https://stackoverflow.com/a/50687120
#
# If we are on a tag
if [ -n "$TRAVIS_TAG" ]; then
  TAG=$(echo $TRAVIS_TAG | tr / _)
# If we are on a PR
elif [ -n "$TRAVIS_PULL_REQUEST_BRANCH" ]; then
  TAG=$(echo $TRAVIS_PULL_REQUEST_BRANCH | tr / _)
# For push builds and hopefully cron builds
elif [ -n "$TRAVIS_BRANCH" ]; then
  TAG=$(echo $TRAVIS_BRANCH | tr / _)
  if [ "${TAG}" = "master" ]; then
    TAG=latest
  fi
else
  # Fallback
  TAG=$(git rev-parse --abbrev-ref HEAD | tr / _)
fi

mkdir vars
if [ -n "$TRAVIS_TAG" ]; then
  # Install the plugin only and use published PyPI packages for the rest
  # Quoting ${TAG} ensures Ansible casts the tag as a string.
  cat > vars/main.yaml << VARSYAML
---
image:
  name: pulp
  tag: "${TAG}"
plugins:
  - name: pulpcore
    source: pulpcore
  - name: pulp_deb
    source: ./pulp_deb
services:
  - name: pulp
    image: "pulp:${TAG}"
    volumes:
      - ./settings:/etc/pulp
VARSYAML
else
  cat > vars/main.yaml << VARSYAML
---
image:
  name: pulp
  tag: "${TAG}"
plugins:
  - name: pulpcore
    source: ./pulpcore
  - name: pulp_deb
    source: ./pulp_deb
services:
  - name: pulp
    image: "pulp:${TAG}"
    volumes:
      - ./settings:/etc/pulp
VARSYAML
fi

cat >> vars/main.yaml << VARSYAML
pulp_settings: null
VARSYAML

if [[ "$TEST" == "pulp" || "$TEST" == "performance" || "$TEST" == "s3" ]]; then
  sed -i -e '/^services:/a \
  - name: pulp-fixtures\
    image: quay.io/pulp/pulp-fixtures:latest' vars/main.yaml
fi

ansible-playbook build_container.yaml
ansible-playbook start_container.yaml
