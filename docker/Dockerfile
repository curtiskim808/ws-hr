# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.4.1
FROM ruby:${RUBY_VERSION}-slim

# Rails app lives here
WORKDIR /app

# Install OS dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      curl \
      libpq-dev \
      libyaml-dev \
      pkg-config \
      postgresql-client \
      libjemalloc2 && \
    rm -rf /var/lib/apt/lists/*

# Environment
ENV RAILS_ENV=development \
    BUNDLE_PATH=/bundle \
    BUNDLE_BIN=/bundle/bin \
    GEM_HOME=/bundle

ENV PATH="${BUNDLE_BIN}:${PATH}"

# Install gems first (cached layer)
COPY Gemfile Gemfile.lock ./
RUN bundle install


# Expose Rails port
EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]
