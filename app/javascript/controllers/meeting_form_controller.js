import { Controller } from "@hotwired/stimulus"

// Moves the "meeting time" marker on every working-hours bar to the chosen slot (24h UTC axis).
export default class extends Controller {
  static targets = ["when", "hours"]

  connect() {
    this.recenter()
  }

  recenter() {
    const date = new Date(this.whenTarget.value)
    const percent = ((date.getUTCHours() * 60 + date.getUTCMinutes()) / 1440) * 100
    this.hoursTarget.style.setProperty("--now", `${percent}%`)
  }
}
