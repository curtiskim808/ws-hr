# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t ws_hr_app .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name ws_hr_app ws_hr_app

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.1
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set build arguments for environment configuration
ARG RAILS_ENV=production
ARG BUNDLE_WITHOUT=development

# Set environment variables
ENV RAILS_ENV="${RAILS_ENV}" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Redeclare ARGs for this build stage
ARG RAILS_ENV=production
ARG BUNDLE_WITHOUT=development

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
# Conditionally set BUNDLE_WITHOUT based on RAILS_ENV
# For development, install all gems; for production, exclude development/test
RUN if [ "$RAILS_ENV" = "development" ]; then \
      bundle install; \
    else \
      BUNDLE_WITHOUT="${BUNDLE_WITHOUT}" bundle install; \
    fi && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/




# Final stage for app image
FROM base

# Redeclare ARG for runtime stage
ARG RAILS_ENV=production

# For development, install build tools needed for gem compilation
RUN if [ "$RAILS_ENV" = "development" ]; then \
      apt-get update -qq && \
      apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
      rm -rf /var/lib/apt/lists /var/cache/apt/archives; \
    fi

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log tmp && \
    # Fix permissions for bundle cache volume (for development)
    mkdir -p "${BUNDLE_PATH}" && chown -R rails:rails "${BUNDLE_PATH}"
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
