import { Controller } from "@hotwired/stimulus"

// Opens a native <dialog> as a modal from a button; Escape and a click on the backdrop close it.
export default class extends Controller {
  static targets = ["dialog", "focus"]

  open() {
    this.dialogTarget.showModal()
    if (this.hasFocusTarget) this.focusTarget.focus()
  }

  close() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
