import { Controller } from "@hotwired/stimulus"

// Records a new shortcut by listening for the keys pressed after clicking a row. Accepts the same
// shapes the server does (single key, two-key chord, or shift+arrow for the one entry that needs
// it); the server still validates, including conflicts.
const ALLOWED = /^[a-z0-9/?]$/
const CHORD_WAIT = 800

export default class extends Controller {
  static targets = ["field", "button", "hint"]

  record({ currentTarget }) {
    this.stop()
    this.active = currentTarget
    this.keys = []
    currentTarget.classList.add("key-capture--recording")
    currentTarget.querySelector("kbd").textContent = "Press keys…"
    this.hint("Press the keys for this shortcut, or Esc to cancel.")
    this.listener = (event) => this.capture(event)
    document.addEventListener("keydown", this.listener, true)
  }

  capture(event) {
    if (["Shift", "Control", "Meta", "Alt"].includes(event.key)) return
    event.preventDefault()
    event.stopPropagation()

    if (event.key === "Escape") return this.cancel()
    if (event.ctrlKey || event.metaKey || event.altKey) return this.hint("Ctrl, Cmd and Alt combinations belong to the browser. Try a plain key or a chord.")

    const shiftArrow = this.active.dataset.shiftArrow === "true"
    const key = event.key.toLowerCase()
    if (shiftArrow) {
      if (event.shiftKey && key.startsWith("arrow")) return this.commit(`shift+${key}`)
      return this.hint("This one needs Shift plus an arrow key.")
    }
    if (event.shiftKey && key !== "?") return this.hint("Shift isn't supported for this shortcut.")
    if (!ALLOWED.test(key)) return this.hint("Use a letter, a digit, / or ?.")

    this.keys.push(key)
    this.active.querySelector("kbd").textContent = this.keys.join(" ").toUpperCase()
    clearTimeout(this.timer)
    if (this.active.dataset.singleKey === "true" || this.keys.length === 2) this.commit(this.keys.join(" "))
    else this.timer = setTimeout(() => this.commit(this.keys.join(" ")), CHORD_WAIT) // one key now, or wait for a second
  }

  commit(spec) {
    const field = this.fieldFor(this.active.dataset.id)
    field.value = spec
    this.active.querySelector("kbd").textContent = this.label(spec)
    this.active.closest(".key-row").classList.toggle("key-row--changed", spec !== field.dataset.default)
    this.hint(`Set to ${this.label(spec)}. Save when you're done.`)
    this.stop()
  }

  cancel() {
    const field = this.fieldFor(this.active.dataset.id)
    this.active.querySelector("kbd").textContent = this.label(field.value)
    this.hint("Cancelled.")
    this.stop()
  }

  reset({ currentTarget }) {
    const field = this.fieldFor(currentTarget.dataset.id)
    field.value = field.dataset.default
    const button = this.buttonTargets.find((el) => el.dataset.id === currentTarget.dataset.id)
    button.querySelector("kbd").textContent = this.label(field.value)
    button.closest(".key-row").classList.remove("key-row--changed")
  }

  stop() {
    clearTimeout(this.timer)
    if (this.listener) document.removeEventListener("keydown", this.listener, true)
    this.listener = null
    this.active?.classList.remove("key-capture--recording")
    this.active = null
  }

  disconnect() {
    this.stop()
  }

  fieldFor(id) {
    return this.fieldTargets.find((el) => el.id === `keybinding_${id}`)
  }

  hint(text) {
    this.hintTarget.textContent = text
  }

  label(spec) {
    const names = { escape: "Esc", ctrl: "Ctrl", shift: "Shift", enter: "Enter", arrowleft: "←", arrowright: "→", arrowup: "↑", arrowdown: "↓" }
    return spec.split(/[ +]/).map((part) => names[part] || part.toUpperCase()).join(" ")
  }
}
