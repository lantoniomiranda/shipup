# Keyboard shortcut registry (config/keybindings.yml) plus each person's remappings.
#
#   Keybindings.keys(:board)              # "g b", or whatever the signed-in person chose
#   Keybindings.label(:board)             # "G B"
#   Keybindings.validate("board" => "g x") # => [] or a list of problems
#
# People may only choose combinations that work in every web browser: a letter, digit, "/" or "?",
# or a two-key chord of those, plus the two modified forms the app itself uses. Anything the
# browser owns (Ctrl/Cmd+letter, Alt combos, Tab, function keys…) is refused.
module Keybindings
  CONFIG = YAML.load_file(Rails.root.join("config/keybindings.yml"), symbolize_names: true).freeze
  CONTEXTS = CONFIG.fetch(:contexts).freeze
  SHORTCUTS = CONFIG.fetch(:shortcuts).transform_values { |entry| entry.merge(context: entry[:context].to_sym) }.freeze

  KEY = %r{[a-z0-9/?]}
  SPEC = /\A(?:#{KEY}(?: #{KEY})?|ctrl\+enter|shift\+arrow(?:left|right|up|down)|arrow(?:left|right|up|down)|escape)\z/
  ARROWS = %w[arrowleft arrowright arrowup arrowdown].freeze

  module_function

  # ---- registry ---------------------------------------------------------------------------
  def all
    SHORTCUTS.map { |id, entry| entry.merge(id: id) }
  end

  def entry(id)
    SHORTCUTS.fetch(id.to_sym) { raise KeyError, "Unknown shortcut #{id}" }
  end

  def default_keys(id) = entry(id)[:keys]
  def fixed?(id) = entry(id)[:fixed] == true
  def customizable = all.reject { |entry| entry[:fixed] }

  # Entries grouped by context in file order, for the help dialog and the settings page.
  def by_context
    all.group_by { |entry| entry[:context] }
  end

  # ---- effective keys ------------------------------------------------------------------------
  def keys(id, user: Current.user)
    override = user&.preference&.keybindings&.dig(id.to_s)
    override.present? && !fixed?(id) && valid_spec?(override) ? override : default_keys(id)
  end

  # "g b" -> "G B", "ctrl+enter" -> "Ctrl Enter", "escape" -> "Esc": what a key cap shows.
  def label(id_or_keys, user: Current.user)
    spec = id_or_keys.is_a?(Symbol) ? keys(id_or_keys, user: user) : id_or_keys.to_s
    spec.split(/[ +]/).map { |part| { "escape" => "Esc", "ctrl" => "Ctrl", "shift" => "Shift", "enter" => "Enter", "arrowleft" => "←", "arrowright" => "→", "arrowup" => "↑", "arrowdown" => "↓" }.fetch(part, part.upcase) }.join(" ")
  end

  # ---- validation -----------------------------------------------------------------------------
  def valid_spec?(spec)
    spec.is_a?(String) && SPEC.match?(spec)
  end

  # What a person may type into the settings form for a remappable entry.
  def assignable_spec?(spec)
    valid_spec?(spec) && !%w[escape ctrl+enter].include?(spec)
  end

  # Problems with a set of overrides ({ "board" => "g x" }), as readable sentences. Empty means fine.
  def validate(overrides)
    effective = SHORTCUTS.keys.index_with { |id| (overrides[id.to_s].presence if overrides.key?(id.to_s)) || default_keys(id) }
    problems = []

    overrides.each do |id, spec|
      next if spec.blank?

      if !SHORTCUTS.key?(id.to_sym) then problems << "“#{id}” is not a shortcut"
      elsif fixed?(id) then problems << "#{entry(id)[:label]} can't be changed"
      elsif entry(id)[:single_key] && spec.include?(" ") then problems << "#{entry(id)[:label]} must be a single key, not a chord"
      elsif entry(id)[:shift_arrow] && !spec.start_with?("shift+arrow") then problems << "#{entry(id)[:label]} must be Shift plus an arrow key"
      elsif !entry(id)[:shift_arrow] && spec.start_with?("shift+") then problems << "#{entry(id)[:label]} can't use Shift"
      elsif !assignable_spec?(spec) then problems << "#{spec.inspect} can't be used for #{entry(id)[:label]}: use a letter, digit, / or ?, or a chord like “g x” (the browser owns Ctrl/Cmd/Alt combinations)"
      end
    end

    problems + conflicts(effective)
  end

  # Pairs of shortcuts that could be active together and would collide (same key, or a single key
  # that is also the first key of a chord).
  def conflicts(effective)
    entries = effective.map { |id, spec| [ id, spec, entry(id)[:context] ] }
    entries.combination(2).filter_map do |(a_id, a_spec, a_context), (b_id, b_spec, b_context)|
      next unless co_active?(a_context, b_context)
      next unless collide?(a_spec, b_spec)

      if a_spec == b_spec
        "#{entry(a_id)[:label]} and #{entry(b_id)[:label]} would both use “#{label(a_spec)}”"
      else
        "#{entry(a_id)[:label]} (“#{label(a_spec)}”) clashes with #{entry(b_id)[:label]} (“#{label(b_spec)}”)"
      end
    end
  end

  def collide?(a, b)
    return true if a == b

    first = ->(spec) { spec.split(" ").first }
    (a.include?(" ") && !b.include?(" ") && first.(a) == b) || (b.include?(" ") && !a.include?(" ") && first.(b) == a)
  end

  # Can two contexts be on screen at once? Global works everywhere (except before sign-in),
  # "project" on every project page, and a page context only with itself.
  def co_active?(a, b)
    a, b = a.to_sym, b.to_sym
    return true if a == b
    return false if a == :sign_in || b == :sign_in # shown before anyone is signed in
    return true if a == :global || b == :global

    in_project = ->(context) { context == :project || CONTEXTS.dig(context, :in_project) }
    (a == :project && in_project.(b)) || (b == :project && in_project.(a))
  end

  # Specs a view may put in data-hotkey: every registered default plus the digits of "open_project".
  def valid_specs
    (all.map { |entry| entry[:keys] } + ("1".."9").to_a).uniq
  end
end
