import { Controller } from "@hotwired/stimulus"

// The "?" cheat-sheet dialog. Closes with Esc, a backdrop click or the close button.
export default class extends Controller {
  static targets = ["root"]

  connect() {
    this.onKeydown = (event) => event.key === "Escape" && !this.rootTarget.hidden && this.close()
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  toggle() {
    this.rootTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.rootTarget.hidden = false
  }

  close() {
    this.rootTarget.hidden = true
  }

  backdrop(event) {
    if (event.target === this.rootTarget) this.close()
  }
}
