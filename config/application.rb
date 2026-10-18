require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Shipup
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Superadmins: emails (comma separated) that may sign in without an invitation, create projects, connect
    # integrations and see every project. Kept in config, not the database, so removing an email revokes it.
    config.x.superadmin_emails = ENV.fetch("SUPERADMIN_EMAILS", "").split(",").map { |email| email.strip.downcase }.reject(&:blank?)

    config.x.product_name = "ohship"

    # English is the default. People choose pt-PT, fr-FR, es-ES or it (Italy).
    # :pt stays available only so rails-i18n's European Portuguese dates and error
    # messages can back pt-PT. pt-BR is not loaded.
    config.i18n.available_locales = [ :en, :"pt-PT", :pt, :"fr-FR", :"es-ES", :it ]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = { :"pt-PT" => [ :pt, :en ], :"fr-FR" => [ :en ], :"es-ES" => [ :en ], :it => [ :en ], :pt => [ :en ] }

    # Render errors through ErrorsController (branded pages) instead of the static public/*.html files.
    config.exceptions_app = routes
    config.active_storage.variant_processor = :disabled # no image variants used

    # Users and meetings span time zones; store UTC and convert per user at the edge.
    config.time_zone = "UTC"

    # Keep generators lean: no helper/asset stubs, tests are written by hand.
    config.generators do |g|
      g.helper false
      g.assets false
      g.test_framework :test_unit, fixture: true
    end
  end
end
