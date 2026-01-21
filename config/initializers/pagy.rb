# Pagy Configuration
# T146: Pagination gem configuration for JSON:API pagination
#
# Pagy is a fast, lightweight pagination library for Rails
# See: https://github.com/ddnexus/pagy

require 'pagy/extras/metadata'

# Default items per page
Pagy::DEFAULT[:items] = 25

# Maximum items per page (prevents abuse)
Pagy::DEFAULT[:max_items] = 100

# Enable metadata for JSON:API responses
Pagy::DEFAULT[:metadata] = [:count, :page, :items, :pages, :last, :from, :to, :prev, :next]
