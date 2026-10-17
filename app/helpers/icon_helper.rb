# Inline SVG icons from app/assets/icons (Lucide, plus the Google/Microsoft marks).
module IconHelper
  ICON_DIR = Rails.root.join("app/assets/icons")
  STROKE_ATTRIBUTES = { fill: "none", stroke: "currentColor", "stroke-width": 1.75, "stroke-linecap": "round", "stroke-linejoin": "round" }.freeze

  # icon("plus", size: 16, class: "x") -> inline <svg> that inherits currentColor.
  def icon(name, size: 16, **options)
    attributes = filled_icon?(name.to_s) ? { fill: "currentColor" } : STROKE_ATTRIBUTES
    tag.svg(icon_markup(name.to_s), **{
      xmlns: "http://www.w3.org/2000/svg", viewBox: icon_view_box(name.to_s), width: size, height: size,
      "aria-hidden": true, class: [ "icon", options.delete(:class) ].compact
    }.merge(attributes).merge(options))
  end

  private

  def icon_source(name)
    (@@icon_sources ||= Concurrent::Map.new).compute_if_absent(name) do
      path = ICON_DIR.join("#{name}.svg")
      raise ArgumentError, "Unknown icon: #{name}" unless path.exist?

      path.read
    end
  end

  # Brand marks are solid shapes rather than Lucide-style outlines.
  def filled_icon?(name)
    icon_source(name).match?(/<svg[^>]*fill="currentColor"/)
  end

  def icon_markup(name)
    inner = icon_source(name)[/<svg[^>]*>(.*)<\/svg>/m, 1].to_s
    inner.html_safe # trusted: files we ship ourselves
  end

  def icon_view_box(name)
    icon_source(name)[/viewBox="([^"]+)"/, 1]
  end
end
