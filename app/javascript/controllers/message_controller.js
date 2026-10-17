import { Controller } from "@hotwired/stimulus"

// Inline editing of one chat message: swaps the text for a form, Esc cancels, Ctrl/Cmd+Enter saves.
export default class extends Controller {
  static targets = ["text", "form"]

  // The edit form starts closed (set here rather than in the HTML so it works with form_with).
  connect() {
    if (this.hasFormTarget) this.formTarget.hidden = true
  }

  edit() {
    this.textTarget.hidden = true
    this.formTarget.hidden = false
    const field = this.formTarget.querySelector("textarea")
    field.focus()
    field.setSelectionRange(field.value.length, field.value.length)
  }

  cancel() {
    this.formTarget.hidden = true
    this.textTarget.hidden = false
  }

  // Tells the composer (which lives elsewhere on the page) who is being replied to.
  reply({ params }) {
    document.dispatchEvent(new CustomEvent("chat:reply", { detail: params }))
  }

  keydown(event) {
    if (event.key === "Escape") {
      event.stopPropagation()
      this.cancel()
    } else if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
      event.preventDefault()
      this.formTarget.requestSubmit()
    }
  }
}
