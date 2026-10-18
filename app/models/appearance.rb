# Turns a person's appearance preferences into what the page needs: data attributes and CSS
# variables on <html> (see tokens.css for the rules they trigger), plus the web font to load.
class Appearance
  FONTS = {
    "exo" => { label: "Exo 2", stack: '"Exo 2", system-ui, sans-serif', google: "Exo+2:wght@400;500;600;700;800" },
    "inter" => { label: "Inter", stack: "Inter, system-ui, sans-serif", google: "Inter:wght@400;500;600;700;800" },
    "atkinson" => { label: "Atkinson Hyperlegible", stack: '"Atkinson Hyperlegible", system-ui, sans-serif', google: "Atkinson+Hyperlegible:wght@400;700" },
    "serif" => { label: "Source Serif", stack: '"Source Serif 4", Georgia, serif', google: "Source+Serif+4:wght@400;600;700" },
    "mono" => { label: "JetBrains Mono", stack: '"JetBrains Mono", ui-monospace, monospace', google: "JetBrains+Mono:wght@400;500;700" },
    "system" => { label: "System UI", stack: "system-ui, sans-serif", google: nil }
  }.freeze
  DENSITY_SCALE = { "compact" => 0.92, "comfortable" => 1.0, "spacious" => 1.08 }.freeze
  TEXT_SCALE = { "small" => 0.94, "default" => 1.0, "large" => 1.1, "larger" => 1.2 }.freeze
  DARK_INK = "#2B211A"

  def self.for(user)
    new(user&.preference)
  end

  def initialize(preference)
    @preference = preference || UserPreference.new
  end

  def font = FONTS.fetch(@preference.font) { FONTS["exo"] }
  def zoom = (DENSITY_SCALE.fetch(@preference.density, 1.0) * TEXT_SCALE.fetch(@preference.text_size, 1.0)).round(4)

  # Attributes for <html>. CSS keys off these (e.g. html[data-corners="round"]).
  def html_attributes
    { data: { bg: @preference.theme_bg, accent: custom_accent? ? "custom" : @preference.theme_accent, font: @preference.font, corners: @preference.corners,
              shadows: @preference.hard_shadows? ? "hard" : "flat", contrast: @preference.high_contrast? ? "high" : "normal",
              motion: @preference.reduce_motion? ? "reduced" : "normal" },
      style: style }
  end

  # Inline custom properties: the zoom for density/text size, and the derived accent family when
  # a custom colour is chosen (soft/ink/tint come from the colour itself with color-mix()).
  def style
    vars = { "--zoom" => zoom }
    if custom_accent?
      color = @preference.custom_accent
      vars.merge!("--accent" => color, "--accent-soft" => "color-mix(in srgb, #{color} 28%, var(--surface))", "--accent-ink" => "color-mix(in srgb, #{color} 62%, var(--ink))",
                  "--accent-tint" => "color-mix(in srgb, #{color} 12%, var(--surface))", "--accent-a55" => "#{color}55", "--on-accent" => readable_on(color))
    end
    vars.map { |name, value| "#{name}: #{value}" }.join("; ")
  end

  # URL of the Google Fonts stylesheet for the chosen font (nil for the system font).
  def font_stylesheet_url
    family = font[:google] or return
    "https://fonts.googleapis.com/css2?family=#{family}&display=swap"
  end

  # Text colour that stays readable on the given accent (WCAG relative luminance).
  def readable_on(hex)
    red, green, blue = hex.delete("#").scan(/../).map { |pair| pair.hex / 255.0 }.map { |channel| channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4 }
    luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    luminance > 0.35 ? DARK_INK : "#FFFFFF"
  end

  private

  def custom_accent? = @preference.theme_accent == "custom" && @preference.custom_accent.present?
end
