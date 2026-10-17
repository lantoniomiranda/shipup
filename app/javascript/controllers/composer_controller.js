import { Controller } from "@hotwired/stimulus"

// Reply box: Enter sends (Shift+Enter adds a line), "r" jumps into the box from anywhere.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.onKeydown = (event) => {
      const typing = ["INPUT", "TEXTAREA", "SELECT"].includes(event.target.tagName) || event.target.isContentEditable
      if (event.key === "r" && !typing && !event.metaKey && !event.ctrlKey && !event.altKey) {
        event.preventDefault()
        this.inputTarget.focus()
      }
    }
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  submitOnEnter(event) {
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }
}
