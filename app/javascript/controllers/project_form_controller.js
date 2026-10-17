import { Controller } from "@hotwired/stimulus"

// Suggests a project key (first three letters of the name) until the user types their own.
export default class extends Controller {
  static targets = ["name", "key"]

  suggestKey() {
    if (this.keyTarget.dataset.touched) return
    this.keyTarget.value = this.nameTarget.value.replace(/[^a-z]/gi, "").slice(0, 3).toUpperCase()
  }

  connect() {
    this.keyTarget.addEventListener("input", () => (this.keyTarget.dataset.touched = "1"))
  }
}
