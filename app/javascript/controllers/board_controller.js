import { Controller } from "@hotwired/stimulus"

// Sprint board: drag cards between columns, or drive it from the keyboard
// (j/k between cards, h/l between columns, Enter opens, Shift+→ advances).
export default class extends Controller {
  static targets = ["column", "card"]
  static values = { token: String }

  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  // --- drag and drop -------------------------------------------------------
  dragStart(event) {
    event.dataTransfer.setData("text/plain", event.currentTarget.dataset.taskUrl)
    event.dataTransfer.effectAllowed = "move"
    event.currentTarget.classList.add("card--dragging")
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("card--dragging")
    this.columnTargets.forEach((column) => column.classList.remove("column--over"))
  }

  dragOver(event) {
    event.preventDefault()
    event.currentTarget.classList.add("column--over")
  }

  dragLeave(event) {
    event.currentTarget.classList.remove("column--over")
  }

  drop(event) {
    event.preventDefault()
    const url = event.dataTransfer.getData("text/plain")
    if (url) this.move(url, event.currentTarget.dataset.status)
  }

  // Submits a real form so Turbo follows the redirect and shows the flash toast.
  move(url, status) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = url
    form.hidden = true
    form.innerHTML = `<input name="_method" value="patch"><input name="task[status]" value="${status}"><input name="authenticity_token" value="${this.tokenValue}">`
    document.body.appendChild(form)
    form.requestSubmit()
  }

  // --- keyboard ------------------------------------------------------------
  onKeydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey || ["INPUT", "TEXTAREA", "SELECT"].includes(event.target.tagName)) return

    const cards = this.cardTargets
    const current = cards.indexOf(document.activeElement)

    if (event.key === "ArrowRight" && event.shiftKey && current >= 0) {
      event.preventDefault()
      const next = cards[current].dataset.nextStatus
      if (next) this.move(cards[current].dataset.taskUrl, next)
      return
    }
    if (event.shiftKey) return

    const columns = this.columnTargets
    const column = current >= 0 ? columns.findIndex((col) => col.contains(cards[current])) : -1
    const cardsIn = (col) => cards.filter((card) => columns[col]?.contains(card))

    if (event.key === "j") this.focus(cards[current + 1] || cards[0], event)
    else if (event.key === "k") this.focus(cards[current - 1] || cards.at(-1), event)
    else if (event.key === "l") this.focus(cardsIn(Math.min(column + 1, columns.length - 1))[0], event)
    else if (event.key === "h") this.focus(cardsIn(Math.max(column - 1, 0))[0], event)
    else if (event.key === "Enter" && current >= 0) cards[current].querySelector("a")?.click()
  }

  focus(card, event) {
    if (!card) return
    event.preventDefault()
    card.focus()
  }
}
