ARG RUBY_VERSION=3.3.1
FROM docker.io/library/ruby:$RUBY_VERSION-slim

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install -y curl git ruby autoconf gcc make zlib1g-dev libffi-dev libreadline-dev libgdbm-dev libssl-dev libyaml-dev libjemalloc2 libpq-dev
