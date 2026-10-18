class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "ohship <no-reply@shipup.local>") }
  layout "mailer"
end
