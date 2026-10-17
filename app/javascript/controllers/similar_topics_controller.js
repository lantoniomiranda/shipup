import { Controller } from "@hotwired/stimulus"

// Loads the "similar topics" turbo frame for whatever has been typed so far (debounced).
export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      this.resultsTarget.src = `${this.urlValue}?q=${encodeURIComponent(this.inputTarget.value)}`
    }, 250)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
