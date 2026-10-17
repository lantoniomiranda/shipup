import { Controller } from "@hotwired/stimulus"

// A dropdown panel toggled by a button; closes on outside click or Escape.
export default class extends Controller {
  static targets = ["button", "panel"]

  connect() {
    this.close = this.close.bind(this)
    this.onKeydown = (event) => event.key === "Escape" && this.close()
    document.addEventListener("click", this.outsideClick = (event) => !this.element.contains(event.target) && this.close())
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClick)
    document.removeEventListener("keydown", this.onKeydown)
  }

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.panelTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }
}
