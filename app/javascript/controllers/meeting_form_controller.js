import { Controller } from "@hotwired/stimulus"

// Meeting scheduler: pick any date and time (in your own time zone), or click a suggested slot.
// Shows what time it is for each invitee, flags people outside their working hours, and moves the
// marker on the working-hours bars (24h UTC axis).
export default class extends Controller {
  static targets = ["date", "time", "hours", "invitee", "summary"]
  static values = { zone: String }

  connect() {
    this.recompute()
  }

  pick({ params: { date, time } }) {
    this.dateTarget.value = date
    this.timeTarget.value = time
    this.recompute()
  }

  recompute() {
    const instant = this.instant()
    if (!instant) return

    const percent = ((instant.getUTCHours() * 60 + instant.getUTCMinutes()) / 1440) * 100
    if (this.hasHoursTarget) this.hoursTarget.style.setProperty("--now", `${percent}%`)

    this.inviteeTargets.forEach((row) => {
      const zone = row.dataset.zone
      const minutes = this.minutesOfDay(instant, zone)
      const outside = minutes < Number(row.dataset.workStart) || minutes >= Number(row.dataset.workEnd)
      row.classList.toggle("invitee--outside", outside)
      row.querySelector("[data-clock]").textContent = this.format(instant, zone)
      row.querySelector(".invitee__time").title = outside ? "Outside their working hours" : "Within their working hours"
    })

    const outsideCount = this.inviteeTargets.filter((row) => row.classList.contains("invitee--outside") && row.querySelector("input[type=checkbox]:checked")).length
    this.summaryTarget.textContent = `${this.format(instant, this.zoneValue, true)} (${this.zoneValue.replaceAll("_", " ")})` +
      (outsideCount ? ` · ${outsideCount} invited ${outsideCount === 1 ? "person is" : "people are"} outside working hours` : "")
  }

  // The instant for the wall-clock date and time typed in, in the organiser's zone.
  instant() {
    if (!this.dateTarget.value || !this.timeTarget.value) return null
    const [y, m, d] = this.dateTarget.value.split("-").map(Number)
    const [hh, mm] = this.timeTarget.value.split(":").map(Number)
    const wallClock = Date.UTC(y, m - 1, d, hh, mm)
    let guess = wallClock
    for (let i = 0; i < 2; i++) guess = wallClock - this.offsetMinutes(guess, this.zoneValue) * 60000
    return new Date(guess)
  }

  offsetMinutes(ms, zone) {
    const parts = Object.fromEntries(new Intl.DateTimeFormat("en-US", { timeZone: zone, hourCycle: "h23", year: "numeric", month: "numeric", day: "numeric", hour: "numeric", minute: "numeric", second: "numeric" })
      .formatToParts(new Date(ms)).map((part) => [part.type, Number(part.value)]))
    return Math.round((Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second) - ms) / 60000)
  }

  minutesOfDay(instant, zone) {
    const parts = Object.fromEntries(new Intl.DateTimeFormat("en-US", { timeZone: zone, hourCycle: "h23", hour: "numeric", minute: "numeric" }).formatToParts(instant).map((p) => [p.type, Number(p.value)]))
    return parts.hour * 60 + parts.minute
  }

  format(instant, zone, long = false) {
    const options = long ? { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" } : { weekday: "short", hour: "2-digit", minute: "2-digit" }
    return new Intl.DateTimeFormat("en-GB", { timeZone: zone, hourCycle: "h23", ...options }).format(instant)
  }
}
