import { Controller } from "@hotwired/stimulus"

// "Replying to …" state of the chat composer. The Reply buttons live on the messages (outside the
// composer element), so the message controller announces them with a document-level "chat:reply" event.
export default class extends Controller {
  static targets = ["banner", "name", "excerpt", "parent", "input"]

  connect() {
    this.onReply = (event) => this.show(event.detail)
    document.addEventListener("chat:reply", this.onReply)
  }

  disconnect() {
    document.removeEventListener("chat:reply", this.onReply)
  }

  show({ id, name, excerpt }) {
    this.parentTarget.value = id
    this.nameTarget.textContent = name
    this.excerptTarget.textContent = excerpt
    this.bannerTarget.hidden = false
    this.inputTarget.focus()
  }

  cancel() {
    this.parentTarget.value = ""
    this.bannerTarget.hidden = true
    this.inputTarget.focus()
  }
}
