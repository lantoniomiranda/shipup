# Renders shortcuts as key caps for the help dialog and Settings > Keyboard.
module KeyboardHelper
  # "g b" -> [G] then [B]; "ctrl+enter" -> [Ctrl] + [Enter]; "shift+arrowright" -> [Shift] + [→].
  # `spec` may also be a list of alternatives (shown as [↑] / [↓]).
  def key_caps(spec, custom: false, fixed: false)
    specs = Array(spec).map(&:to_s)
    classes = [ "keys", ("keys--custom" if custom), ("keys--fixed" if fixed) ].compact
    content_tag(:span, class: classes, data: { keys: specs.join("|") }) do
      safe_join(specs.map { |one| safe_join(chord_caps(one), tag.span(t("shortcuts.then"), class: "keys__sep keys__sep--then")) }, tag.span("/", class: "keys__sep"))
    end
  end

  # Text a person can search for in the help dialog and settings filter.
  def shortcut_search_text(label, spec, title)
    [ label, Array(spec).map { |one| Keybindings.label(one) }, title ].flatten.join(" ").downcase
  end

  def shortcut_context_hint(context)
    t("shortcuts.contexts.#{context}")
  end

  def shortcut_reference_label(entry)
    t("shortcuts.reference.#{entry[:id]}")
  end

  private

  def chord_caps(spec)
    spec.split(" ").map do |step|
      safe_join(step.split("+").map { |key| content_tag(:kbd, Keybindings.label(key), class: "key") }, tag.span("+", class: "keys__sep keys__sep--plus"))
    end
  end
end
