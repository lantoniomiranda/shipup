import { Controller } from "@hotwired/stimulus"

// Settings > Keyboard. Click a key cap, press the new keys, save. Besides recording it:
//   - filters rows and sections as you type (label, key, section),
//   - marks the section you are reading in the sticky jump bar,
//   - shows customised / unsaved state per row and warns about clashes before the server does.
// It accepts the same shapes the server does (single key, two-key chord, or shift+arrow for the one
// entry that needs it); the server still validates, including conflicts, and has the last word.
// Texts come from the locale files through data-key-settings-messages-value.
const ALLOWED = /^[a-z0-9/?]$/
const CHORD_WAIT = 800
const NAMES = { escape: "Esc", ctrl: "Ctrl", shift: "Shift", enter: "Enter", tab: "Tab", space: "Space", arrowleft: "←", arrowright: "→", arrowup: "↑", arrowdown: "↓" }

export default class extends Controller {
  static targets = ["field", "button", "hint", "row", "section", "navLink", "filter", "empty", "save", "resetButton", "form", "dirty"]
  static values = { messages: Object, coactive: Object }

  connect() {
    this.validate()
    this.updateDirty()
    this.spy()
  }

  disconnect() {
    this.stop()
    this.observer?.disconnect()
  }

  // ---- recording ---------------------------------------------------------------------------
  record({ currentTarget }) {
    this.stop()
    this.active = currentTarget
    this.keys = []
    currentTarget.classList.add("key-capture--recording")
    currentTarget.replaceChildren(this.text(this.messages.press_keys, "key-capture__prompt"))
    this.hint(this.messages.recording)
    this.listener = (event) => this.capture(event)
    document.addEventListener("keydown", this.listener, true)
  }

  capture(event) {
    if (["Shift", "Control", "Meta", "Alt"].includes(event.key)) return
    event.preventDefault()
    event.stopPropagation()

    if (event.key === "Escape") return this.cancel()
    if (event.ctrlKey || event.metaKey || event.altKey) return this.hint(this.messages.browser_owned)

    const shiftArrow = this.active.dataset.shiftArrow === "true"
    const key = event.key.toLowerCase()
    if (shiftArrow) {
      if (event.shiftKey && key.startsWith("arrow")) return this.commit(`shift+${key}`)
      return this.hint(this.messages.need_shift_arrow)
    }
    if (event.shiftKey && key !== "?") return this.hint(this.messages.no_shift)
    if (!ALLOWED.test(key)) return this.hint(this.messages.bad_key)

    this.keys.push(key)
    this.active.replaceChildren(this.caps(this.keys.join(" ")))
    clearTimeout(this.timer)
    if (this.active.dataset.singleKey === "true" || this.keys.length === 2) this.commit(this.keys.join(" "))
    else this.timer = setTimeout(() => this.commit(this.keys.join(" ")), CHORD_WAIT) // one key now, or wait for a second
  }

  commit(spec) {
    const button = this.active
    this.set(button.dataset.id, spec)
    this.stop()
    this.hint(this.messages.set_to.replace("%{keys}", this.label(spec)))
    this.validate()
    this.updateDirty()
  }

  cancel() {
    const field = this.fieldFor(this.active.dataset.id)
    this.active.replaceChildren(this.caps(field.value))
    this.stop()
    this.hint(this.messages.idle)
  }

  reset({ currentTarget }) {
    const field = this.fieldFor(currentTarget.dataset.id)
    this.set(currentTarget.dataset.id, field.dataset.default)
    this.hint(this.messages.reset_done.replace("%{keys}", this.label(field.dataset.default)))
    this.validate()
    this.updateDirty()
  }

  // Writes a spec into the hidden field, the cap and the row state.
  set(id, spec) {
    const field = this.fieldFor(id)
    const row = this.rowFor(id)
    const custom = spec !== field.dataset.default
    field.value = spec
    row.dataset.spec = spec
    row.classList.toggle("key-row--changed", custom)
    row.classList.toggle("key-row--unsaved", spec !== field.dataset.initial)
    const button = this.buttonTargets.find((el) => el.dataset.id === id)
    button.replaceChildren(this.caps(spec, custom))
    const reset = row.querySelector("[data-key-settings-target~=resetButton]")
    if (reset) reset.hidden = !custom
  }

  stop() {
    clearTimeout(this.timer)
    if (this.listener) document.removeEventListener("keydown", this.listener, true)
    this.listener = null
    this.active?.classList.remove("key-capture--recording")
    this.active = null
  }

  // ---- clashes -----------------------------------------------------------------------------
  // Mirrors Keybindings.conflicts: same key, or a single key that starts a chord, among shortcuts
  // that can be on screen together.
  validate() {
    const rows = this.rowTargets.filter((row) => row.dataset.spec)
    let clashes = 0
    rows.forEach((row) => {
      const other = rows.find((candidate) => candidate !== row && this.coactive(row.dataset.context, candidate.dataset.context) && this.collide(row.dataset.spec, candidate.dataset.spec))
      const warn = row.querySelector("[data-key-settings-target~=warn]")
      row.classList.toggle("key-row--clash", !!other)
      warn.hidden = !other
      warn.textContent = other ? this.messages.conflict.replace("%{other}", other.dataset.label) : ""
      if (other) clashes++
    })
    this.clashes = clashes
    this.saveTarget.disabled = clashes > 0
    this.saveTarget.title = clashes > 0 ? this.messages.fix_conflicts : ""
    if (clashes > 0) this.hint(this.messages.fix_conflicts)
  }

  coactive(a, b) {
    return (this.coactiveValue[a] || []).includes(b)
  }

  collide(a, b) {
    if (a === b) return true
    const first = (spec) => spec.split(" ")[0]
    return (a.includes(" ") && !b.includes(" ") && first(a) === b) || (b.includes(" ") && !a.includes(" ") && first(b) === a)
  }

  // ---- filter and jump bar -------------------------------------------------------------------
  filter() {
    const query = this.filterTarget.value.toLowerCase().trim().replace(/\s+/g, " ") // "g b" finds the chord, "board" the action
    this.rowTargets.forEach((row) => {
      row.hidden = !(row.dataset.search || "").includes(query)
    })
    let visible = 0
    this.sectionTargets.forEach((section) => {
      const shown = section.querySelectorAll("[data-key-settings-target~=row]:not([hidden])").length
      section.hidden = shown === 0
      visible += shown
      this.navLinkTargets.find((link) => link.dataset.context === section.dataset.context)?.toggleAttribute("hidden", shown === 0)
    })
    this.emptyTarget.hidden = visible > 0
  }

  // Marks the jump-bar link of the section nearest the top of the scrolling area.
  spy() {
    this.observer = new IntersectionObserver((entries) => {
      entries.filter((entry) => entry.isIntersecting).forEach((entry) => this.mark(entry.target.dataset.context))
    }, { root: this.element, rootMargin: "-120px 0px -65% 0px" })
    this.sectionTargets.forEach((section) => this.observer.observe(section))
  }

  mark(context) {
    this.navLinkTargets.forEach((link) => {
      const current = link.dataset.context === context
      link.classList.toggle("key-nav__link--current", current)
      if (current) link.setAttribute("aria-current", "true"); else link.removeAttribute("aria-current")
      if (current) this.keepVisible(link)
    })
  }

  keepVisible(link) {
    const bar = link.parentElement
    if (bar.scrollWidth <= bar.clientWidth) return
    bar.scrollTo({ left: link.offsetLeft - bar.clientWidth / 2 + link.clientWidth / 2, behavior: "smooth" })
  }

  // ---- helpers -----------------------------------------------------------------------------
  get messages() {
    return this.messagesValue
  }

  // "Unsaved changes: 2" beside the Save button; empty when everything is saved.
  updateDirty() {
    const unsaved = this.element.querySelectorAll(".key-row--unsaved").length
    this.dirtyTarget.textContent = unsaved > 0 ? this.messages.unsaved.replace("%{count}", unsaved) : ""
    this.dirtyTarget.hidden = unsaved === 0
  }

  fieldFor(id) {
    return this.fieldTargets.find((el) => el.id === `keybinding_${id}`)
  }

  rowFor(id) {
    return this.rowTargets.find((el) => el.dataset.id === id)
  }

  hint(text) {
    this.hintTarget.textContent = text
  }

  text(text, className) {
    const span = document.createElement("span")
    span.className = className
    span.textContent = text
    return span
  }

  label(spec) {
    return spec.split(/[ +]/).map((part) => NAMES[part] || part.toUpperCase()).join(" ")
  }

  // Same markup as KeyboardHelper#key_caps.
  caps(spec, custom = false) {
    const wrap = document.createElement("span")
    wrap.className = custom ? "keys keys--custom" : "keys"
    spec.split(" ").forEach((step, index) => {
      if (index > 0) wrap.append(this.text(this.messages.then, "keys__sep keys__sep--then"))
      step.split("+").forEach((key, position) => {
        if (position > 0) wrap.append(this.text("+", "keys__sep keys__sep--plus"))
        const cap = document.createElement("kbd")
        cap.className = "key"
        cap.textContent = NAMES[key] || key.toUpperCase()
        wrap.append(cap)
      })
    })
    return wrap
  }
}
