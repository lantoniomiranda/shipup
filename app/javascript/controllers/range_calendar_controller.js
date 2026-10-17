import { Controller } from "@hotwired/stimulus"

// Pick a start and end day on the month grid; shows the working-day count and what is left of the allowance.
export default class extends Controller {
  static targets = ["day", "start", "end", "kind", "range", "days", "left", "submit"]
  static values = { balances: Object }

  connect() {
    this.update()
  }

  pick({ currentTarget }) {
    const date = currentTarget.dataset.date
    if (!this.startTarget.value || this.endTarget.value) {
      this.startTarget.value = date
      this.endTarget.value = ""
    } else if (date < this.startTarget.value) {
      this.endTarget.value = this.startTarget.value
      this.startTarget.value = date
    } else {
      this.endTarget.value = date
    }
    this.update()
  }

  update() {
    const start = this.startTarget.value
    const end = this.endTarget.value || start
    this.dayTargets.forEach((el) => {
      const date = el.dataset.date
      el.classList.toggle("calendar__day--in-range", !!start && date >= start && date <= end)
      el.classList.toggle("calendar__day--edge", date === start || date === end)
    })

    if (!start) return
    const days = this.workingDays(start, end)
    const kind = this.kindTargets.find((el) => el.checked)?.value || "vacation"
    const left = this.balancesValue[kind] ?? 0
    this.rangeTarget.textContent = start === end ? this.format(start) : `${this.format(start)} – ${this.format(end)}`
    this.daysTarget.textContent = `${days} working ${days === 1 ? "day" : "days"}`
    this.leftTarget.textContent = `${left} ${kind} days left, ${left - days} after this request`
    this.submitTarget.disabled = days > left
  }

  workingDays(start, end) {
    let count = 0
    for (let d = new Date(`${start}T00:00:00Z`); d <= new Date(`${end}T00:00:00Z`); d.setUTCDate(d.getUTCDate() + 1)) {
      if (![0, 6].includes(d.getUTCDay())) count++
    }
    return count
  }

  format(iso) {
    return new Date(`${iso}T00:00:00Z`).toLocaleDateString("en-GB", { day: "numeric", month: "short", timeZone: "UTC" })
  }
}
