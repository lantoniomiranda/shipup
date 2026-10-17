import { Controller } from "@hotwired/stimulus"

// Clicks a target when its shortcut is pressed (ignored while typing, except for modified combos).
//
//   <div data-controller="hotkey">
//     <a data-hotkey-target="trigger" data-hotkey-key="g d">   chord: press g, then d
//     <button data-hotkey-target="trigger" data-hotkey-key="ctrl+enter">
//     <a data-hotkey-target="trigger" data-hotkey-key="escape">
//
// "ctrl" also matches Cmd, so shortcuts feel native on macOS.
const CHORD_TIMEOUT = 900

export default class extends Controller {
  static targets = ["trigger"]

  connect() {
    this.buffer = []
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    const modified = event.ctrlKey || event.metaKey
    if (event.altKey || ["Control", "Meta", "Shift", "Alt"].includes(event.key)) return
    if (this.isTyping(event.target) && !modified && event.key !== "Escape") return

    const key = event.key.toLowerCase()
    const now = Date.now()
    this.buffer = this.buffer.filter((entry) => now - entry.at < CHORD_TIMEOUT).concat({ key, at: now })
    const sequence = this.buffer.map((entry) => entry.key).join(" ")

    const trigger = this.triggerTargets.find((el) => {
      const spec = el.dataset.hotkeyKey
      return spec.startsWith("ctrl+") ? modified && spec === `ctrl+${key}` : !modified && (spec === key || spec === sequence)
    })

    if (trigger) {
      event.preventDefault()
      this.buffer = []
      trigger.click()
    }
  }

  isTyping(el) {
    return el.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(el.tagName)
  }
}
