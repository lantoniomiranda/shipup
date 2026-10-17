import { Controller } from "@hotwired/stimulus"

// Clicks a target when its key is pressed anywhere on the page (ignored while typing).
// Usage: data-controller="hotkey" on a wrapper, data-hotkey-target="trigger" data-hotkey-key="g" on each button.
export default class extends Controller {
  static targets = ["trigger"]

  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  onKeydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey || this.isTyping(event.target)) return

    const trigger = this.triggerTargets.find((el) => el.dataset.hotkeyKey === event.key.toLowerCase())
    if (trigger) {
      event.preventDefault()
      trigger.click()
    }
  }

  isTyping(el) {
    return el.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(el.tagName)
  }
}
