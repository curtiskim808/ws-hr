source "https://rubygems.org"

ruby "3.4.1"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.4"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache and Active Job
gem "solid_cache"
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

# Authentication & Authorization
gem "devise", "~> 4.9"
gem "devise-jwt", "~> 0.11"

# State machines
gem "aasm", "~> 5.5"

# JSON API serialization
gem "jsonapi-serializer", "~> 2.2"

# Pagination
gem "pagy", "~> 8.0"

# Background jobs (using solid_queue instead of sidekiq for Rails 8)
# Note: solid_queue already included above

# AWS SNS for notifications
gem "aws-sdk-sns", "~> 1.70"

gem "rswag-ui"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Interactive debugging console [https://github.com/pry/pry]
  gem "pry"
  gem "pry-byebug"
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Testing framework
  gem "rspec-rails", "~> 8.0"
  gem "shoulda-matchers", "~> 6.0"
  gem "database_cleaner-active_record", "~> 2.2"
  gem "rswag-specs"
end

group :development do
  gem "listen", "~> 3.8"
  gem "swagger_ui_engine", "~> 1.1.2"
end

group :test do
  gem "simplecov", require: false
  gem "coveralls_reborn", require: false
end
