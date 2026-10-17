import { Controller } from "@hotwired/stimulus"

// Counts up from an ISO timestamp, rendering HH:MM:SS (used by the running-timer pill).
export default class extends Controller {
  static values = { started: String }

  connect() {
    this.render()
    this.timer = setInterval(() => this.render(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  render() {
    const seconds = Math.max(0, Math.floor((Date.now() - new Date(this.startedValue).getTime()) / 1000))
    const pad = (n) => String(n).padStart(2, "0")
    this.element.textContent = `${pad(Math.floor(seconds / 3600))}:${pad(Math.floor(seconds / 60) % 60)}:${pad(seconds % 60)}`
  }
}
