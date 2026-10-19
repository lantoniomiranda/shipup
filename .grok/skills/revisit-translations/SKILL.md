---
name: revisit-translations
description: >
  Keep ShipUp locale catalogs in sync with English. Compare config/locales/en.yml
  with pt-PT, fr-FR, es-ES, and it, then add missing keys, update keys whose
  English text changed, and delete keys English no longer has. Write idiomatic
  copy (Portugal Portuguese, not Brazilian). Use when the user runs
  /revisit-translations, or asks to update, sync, add, or remove translations.
---

# revisit-translations

English in `config/locales/en.yml` is the only source of truth. Offered catalogs are `config/locales/pt-PT.yml`, `fr-FR.yml`, `es-ES.yml`, and `it.yml` (`Locale::OFFERED`). `:pt` is a hidden rails-i18n fallback, not a catalog and not a menu choice. Do not add `pt-BR`.

Other agents edit this tree. Re-read `en.yml` and each catalog immediately before you change them, and again before you finish.

## Sync

Flatten both trees (hashes recurse, everything else is a leaf). Then:

- **Create** a leaf that English has and the catalog lacks. Translate it.
- **Update** a leaf whose English value changed since that catalog was last committed. `git diff <commit that last touched the catalog> -- config/locales/en.yml` is the list. Retranslate those values. Leave untouched English values alone.
- **Delete** a leaf the catalog has and English does not.

Also search `app/` for `t(` and `I18n.t`. A literal key with no English leaf is missing: add it to `en.yml` first, then to the other catalogs. A dynamic key (`roles.#{role}`) is covered when its prefix exists. `date.abbr_day_names` comes from rails-i18n; do not copy it into our files.

Match the English shape. Same nesting, `one`/`other` only, the same `%{placeholders}`, and the same tags on `_html` values. Integer keys such as `400` stay unquoted. Keep each catalog's existing `date.formats`, `time.formats`, and `date.narrow_day_names` unless English added a format key.

`locale.plural_style` is `french` in `fr-FR` and `standard` elsewhere. French counts 0 and 1 with `:one`, so a `:one` string that contains `%{count}` must still read correctly for 0. `locale.names.*` stay the native names already in English.

A hardcoded user-facing string in a view, mailer, or flash becomes a key. Edit only that string when the file also contains someone else's uncommitted work.

`public/*.html` and the sign-in sunset panel stay English.

## Voice

Write what a product team in that country would ship. Do not calque.

- **pt-PT:** no "você". "A sua" or an infinitive ("Inicie sessão"). Guardar, palavra-passe, e-mail, utilizador, equipa, contacto, separador, planear. Not salvar, senha, usuário, time, contato, aba, planejar. Sequência, tópico, quadro, ausências, cronograma. Em curso, Pronto a publicar, Erro for the bug flag. Baixa for sick leave.
- **fr-FR:** vous. Narrow no-break space (U+202F) before `:`, `;`, `!`, `?` in prose, not inside `%{…}`, tags, or strftime. Typographic apostrophe. Séquence, sujets, tableau, planning, congés. En cours, Prêt à déployer, Bogue. Morning and afternoon are both Bonjour; evening is Bonsoir.
- **es-ES:** tú, with ¿ and ¡. Secuencia, temas, tablero, cronograma, ausencias. En curso, Listo para desplegar, Fallo. Contraseña. Not Latin American "computadora" or "usted".
- **it:** tu. Sequenza, argomenti, bacheca, cronologia, assenze. In corso, Pronto per il rilascio, Bug.

Keep ShipUp, Sprint, Backlog, XP, Google, Microsoft, GitHub, Zoom, Teams, Meet, Chrome, Edge, Firefox, Safari, and sample names. `people.product` is ShipUp. `people.ago` wraps `time_ago_in_words`, which already has no "ago": há %{time}, il y a %{time}, hace %{time}, %{time} fa.

Model errors that Rails appends to an attribute stay lowercase fragments. Errors added to `:base` are full sentences. `enums.time_off_kind_inline` stays a lowercase word that fits "days of %{kind}".

## Check

```ruby
ruby -ryaml -e '
def flat(h, p=nil, o={})
  h.each { |k,v| path=[p,k].compact.join("."); v.is_a?(Hash) ? flat(v, path, o) : o[path]=v }
  o
end
en = flat(YAML.safe_load_file("config/locales/en.yml").fetch("en"))
%w[pt-PT fr-FR es-ES it].each do |code|
  other = flat(YAML.safe_load_file("config/locales/#{code}.yml").fetch(code))
  missing = en.keys - other.keys
  extra = other.keys - en.keys
  bad = en.select { |k,v| v.is_a?(String) && v.scan(/%\{[^}]+\}/).sort != other[k].to_s.scan(/%\{[^}]+\}/).sort }
  abort "#{code} missing #{missing.inspect}" unless missing.empty?
  abort "#{code} extra #{extra.inspect}" unless extra.empty?
  abort "#{code} placeholders #{bad.keys.inspect}" unless bad.empty?
end
puts "OK #{en.size}"
'
```

Then `bin/rails test test/models/locale_test.rb`. Fix the catalogs until both pass.

## Commits

Commit only when the user asks. One commit per catalog you changed. Stage that file and nothing else. Never stage a file whose diff is mostly another agent's work, and do not stash or check out their changes to get a clean tree.
