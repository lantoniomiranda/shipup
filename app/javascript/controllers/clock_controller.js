import { Controller } from "@hotwired/stimulus"

// Keeps each teammate's local time current. Elements carry data-zone="Europe/Lisbon".
export default class extends Controller {
  static targets = ["zone", "time"]

  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 15_000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    const now = new Date()
    this.zoneTargets.forEach((el) => {
      const zone = el.dataset.zone
      const time = el.querySelector("[data-clock-target='time']")
      time.textContent = new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", hour12: false, timeZone: zone }).format(now)
    })
  }
}
