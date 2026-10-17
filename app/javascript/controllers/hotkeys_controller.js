import { Controller } from "@hotwired/stimulus"

// The one global keyboard shortcut handler (mounted on <body>). It looks for elements marked
//   data-hotkey="g b"          chord: press g, then b
//   data-hotkey="n"            single key
//   data-hotkey="ctrl+enter"   modified key (ctrl also matches Cmd on macOS)
// and clicks the first visible, enabled one. The shortcuts are listed in config/keybindings.yml.
// Nothing fires while typing in a field (except Esc and modified keys) or while a dialog is open.
const CHORD_TIMEOUT = 900

export default class extends Controller {
  connect() {
    this.buffer = []
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    if (event.altKey || event.defaultPrevented || ["Control", "Meta", "Shift", "Alt"].includes(event.key)) return
    if (document.querySelector(".spotlight:not([hidden]), .keyhelp:not([hidden])")) return

    const modified = event.ctrlKey || event.metaKey
    const key = event.key.toLowerCase()
    if (this.isTyping(event.target) && !modified && key !== "escape") return

    const spec = this.specFor(event, key, modified)
    const element = this.find(spec)
    if (element) {
      event.preventDefault()
      this.buffer = []
      element.click()
    }
  }

  // The spec this key press would match: "ctrl+enter", "shift+arrowright", a chord, or a single key.
  specFor(event, key, modified) {
    if (modified) return `ctrl+${key}`
    if (event.shiftKey && key.startsWith("arrow")) return `shift+${key}`

    const now = Date.now()
    this.buffer = this.buffer.filter((entry) => now - entry.at < CHORD_TIMEOUT).concat({ key, at: now })
    const chord = this.buffer.map((entry) => entry.key).join(" ")
    // Prefer a chord ("g b") over a single key ("b") when one is registered on the page.
    return this.find(chord) ? chord : key
  }

  find(spec) {
    return [...document.querySelectorAll("[data-hotkey]")].find((el) => el.dataset.hotkey === spec && this.usable(el))
  }

  usable(el) {
    return !el.disabled && el.getAttribute("aria-disabled") !== "true" && !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length)
  }

  isTyping(el) {
    return el.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(el.tagName)
  }
}
