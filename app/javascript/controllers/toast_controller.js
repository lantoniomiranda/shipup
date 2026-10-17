import { Controller } from "@hotwired/stimulus"

// Fades a flash message out after a few seconds.
export default class extends Controller {
  connect() {
    this.timer = setTimeout(() => this.element.classList.add("toast--leaving"), 4000)
    this.remove = setTimeout(() => this.element.remove(), 4400)
  }

  disconnect() {
    clearTimeout(this.timer)
    clearTimeout(this.remove)
  }
}
