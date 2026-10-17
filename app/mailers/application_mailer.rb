class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "ShipUp <no-reply@shipup.local>") }
  layout "mailer"
end
