# Keyboard shortcut registry loaded from config/keybindings.yml (see that file for the rules).
module Keybindings
  REGISTRY = YAML.load_file(Rails.root.join("config/keybindings.yml"), symbolize_names: true).freeze

  module_function

  def all = REGISTRY.flat_map { |group, entries| entries.map { |id, entry| entry.merge(id: id, group: group) } }
  def groups = REGISTRY
  def keys(id) = all.find { |entry| entry[:id] == id.to_sym }&.fetch(:keys) || raise(KeyError, "Unknown shortcut #{id}")

  # "g b" -> "G B", "ctrl+enter" -> "Ctrl Enter", "escape" -> "Esc": what the key hint shows.
  def label(id_or_keys)
    spec = id_or_keys.is_a?(Symbol) ? keys(id_or_keys) : id_or_keys.to_s
    spec.split(/[ +]/).map { |part| { "escape" => "Esc", "ctrl" => "Ctrl", "shift" => "Shift", "enter" => "Enter", "arrowleft" => "←", "arrowright" => "→" }.fetch(part, part.upcase) }.join(" ")
  end

  # Every key spec a view may put in data-hotkey. Registered specs plus the letters/digits that
  # the page-level entries describe as families ("K previous", "M for Microsoft", projects 1–9).
  EXTRA_KEYS = (%w[k h m arrowright] + ("1".."9").to_a).freeze

  def valid_specs
    (all.map { |entry| entry[:keys] } + EXTRA_KEYS).uniq
  end
end
