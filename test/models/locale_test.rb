require "test_helper"

class LocaleTest < ActiveSupport::TestCase
  test "a chosen language beats the browser" do
    assert_equal "pt-PT", Locale.resolve(cookie: "pt-PT", accept_language: "fr-FR,fr;q=0.9")
    assert_equal "en", Locale.resolve(cookie: "en", accept_language: "pt-PT,pt;q=0.9")
  end

  test "unknown cookies and regions fall through" do
    assert_nil Locale.pick("pt-BR")
    assert_nil Locale.pick("nope")
    assert_equal "fr-FR", Locale.resolve(cookie: "nope", accept_language: "pt-BR, fr;q=0.8")
    assert_equal :en, Locale.resolve(cookie: nil, accept_language: "pt-BR, es-MX, it-CH")
    assert_equal :en, Locale.resolve(cookie: nil, accept_language: nil)
  end

  test "language tags map onto the locales we ship" do
    {
      "en" => "en", "en-GB" => "en", "EN-us" => "en",
      "pt" => "pt-PT", "pt-PT" => "pt-PT", "PT-pt" => "pt-PT",
      "fr" => "fr-FR", "fr-FR" => "fr-FR",
      "es" => "es-ES", "es-ES" => "es-ES",
      "it" => "it", "it-IT" => "it", "it_IT" => "it"
    }.each { |tag, locale| assert_equal locale, Locale.match_tag(tag), tag }

    %w[pt-BR fr-CA fr-CH es-MX es-419 it-CH de zh-CN].each { |tag| assert_nil Locale.match_tag(tag), tag }
  end

  test "html lang uses a regional tag for Italian" do
    assert_equal "it-IT", Locale::HTML_LANG.fetch("it")
    assert_equal "pt-PT", Locale::HTML_LANG.fetch("pt-PT")
    assert_equal "fr-FR", Locale::HTML_LANG.fetch("fr-FR")
  end

  test "shipped catalogs cover every English string" do
    english = flatten(load_catalog("en"))

    Locale::OFFERED.each do |code|
      next if code == "en"

      path = Rails.root.join("config/locales/#{code}.yml")
      next unless path.exist?

      other = flatten(load_catalog(code))
      missing = english.keys - other.keys
      extra = other.keys - english.keys
      assert_empty missing, "#{code} is missing #{missing.first(12).join(', ')}"
      assert_empty extra, "#{code} has extra #{extra.first(12).join(', ')}"

      english.each do |key, value|
        next unless value.is_a?(String)

        assert_equal placeholders(value), placeholders(other.fetch(key)), "#{code} placeholders for #{key}"
      end

      assert_equal 7, other.fetch("date.narrow_day_names").size, "#{code} narrow weekdays"
    end
  end

  test "french counts zero with the singular" do
    skip unless Rails.root.join("config/locales/fr-FR.yml").exist?

    assert_equal "french", I18n.t("locale.plural_style", locale: :"fr-FR")
    assert_equal "standard", I18n.t("locale.plural_style", locale: :en)
    one = I18n.t("home.projects", count: 1, locale: :"fr-FR")
    zero = I18n.t("home.projects", count: 0, locale: :"fr-FR")
    assert_equal one.sub("1", "0"), zero
  end

  private

  def load_catalog(code)
    YAML.safe_load_file(Rails.root.join("config/locales/#{code}.yml")).fetch(code)
  end

  def flatten(hash, prefix = nil)
    hash.each_with_object({}) do |(key, value), out|
      path = [ prefix, key ].compact.join(".")
      if value.is_a?(Hash)
        out.merge!(flatten(value, path))
      else
        out[path] = value
      end
    end
  end

  def placeholders(text)
    text.scan(/%\{[^}]+\}/).sort
  end
end
