# Which language this request uses. Portugal is explicit (`pt-PT`); a Brazilian
# Accept-Language tag is not treated as European Portuguese.
class Locale
  Option = Data.define(:code, :name)

  # What the language menu offers. :pt is a hidden fallback for rails-i18n, not a choice.
  OFFERED = %w[en pt-PT fr-FR es-ES it].freeze
  HTML_LANG = { "en" => "en", "pt-PT" => "pt-PT", "fr-FR" => "fr-FR", "es-ES" => "es-ES", "it" => "it-IT" }.freeze

  def self.options
    OFFERED.map { |code| Option.new(code, I18n.t("locale.names.#{code}", locale: code)) }
  end

  def self.html_lang
    HTML_LANG.fetch(I18n.locale.to_s, I18n.locale.to_s)
  end

  # Cookie wins. Otherwise the first Accept-Language tag we actually support.
  def self.resolve(cookie:, accept_language:)
    pick(cookie) || from_header(accept_language) || I18n.default_locale
  end

  def self.pick(value)
    OFFERED.find { |locale| locale.casecmp?(value.to_s) }
  end

  def self.from_header(header)
    return if header.blank?

    header.split(",").filter_map { |part| match_tag(part.split(";").first) }.first
  end

  # Region tags we do not ship (pt-BR, fr-CA, es-MX, …) fall through to the next choice.
  def self.match_tag(tag)
    down = tag.to_s.strip.tr("_", "-").downcase
    return if down.empty?

    case down
    when "en", /^en-/ then "en"
    when "pt", "pt-pt" then "pt-PT"
    when "fr", "fr-fr" then "fr-FR"
    when "es", "es-es" then "es-ES"
    when "it", "it-it" then "it"
    end
  end
end
