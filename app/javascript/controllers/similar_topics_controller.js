import { Controller } from "@hotwired/stimulus"

// Loads the "similar topics" turbo frame for whatever has been typed so far, title and post (debounced).
export default class extends Controller {
  static targets = ["input", "body", "results"]
  static values = { url: String }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      const body = this.hasBodyTarget ? this.bodyTarget.value : ""
      this.resultsTarget.src = `${this.urlValue}?q=${encodeURIComponent(this.inputTarget.value)}&body=${encodeURIComponent(body)}`
    }, 250)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
