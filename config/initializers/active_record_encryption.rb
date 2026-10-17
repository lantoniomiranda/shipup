# Integration tokens are encrypted at rest. Production must supply real keys
# (generate with `bin/rails db:encryption:init`); dev and test use fixed ones.
Rails.application.configure do
  if Rails.env.production?
    config.active_record.encryption.primary_key = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY")
    config.active_record.encryption.deterministic_key = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY")
    config.active_record.encryption.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT")
  else
    config.active_record.encryption.primary_key = "dev-primary-key-not-secret"
    config.active_record.encryption.deterministic_key = "dev-deterministic-key-not-secret"
    config.active_record.encryption.key_derivation_salt = "dev-key-derivation-salt-not-secret"
  end
end
