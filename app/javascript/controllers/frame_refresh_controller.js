import { Controller } from "@hotwired/stimulus"

// Reloads a turbo frame every so often while the page is visible, so what it shows (e.g. related
// topics) follows a discussion other people are still writing in.
export default class extends Controller {
  static values = { every: { type: Number, default: 30 } }

  connect() {
    this.timer = setInterval(() => {
      if (!document.hidden && this.element.src) this.element.reload()
    }, this.everyValue * 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }
}
