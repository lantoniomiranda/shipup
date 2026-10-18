import { Controller } from "@hotwired/stimulus"

// Drag and drop reordering of the project tabs. The order is saved per person (PATCH url) as soon as
// a tab is dropped; links still work normally when clicked.
export default class extends Controller {
  static targets = ["tab"]
  static values = { url: String }

  start(event) {
    this.dragged = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.dragged.dataset.tabKey)
    requestAnimationFrame(() => this.dragged.classList.add("tab--dragging"))
  }

  over(event) {
    if (!this.dragged) return
    event.preventDefault()
    const target = event.currentTarget
    if (target === this.dragged) return
    const after = event.clientX > target.getBoundingClientRect().left + target.offsetWidth / 2
    target.parentNode.insertBefore(this.dragged, after ? target.nextSibling : target)
  }

  drop(event) {
    event.preventDefault()
  }

  finish() {
    if (!this.dragged) return
    this.dragged.classList.remove("tab--dragging")
    this.dragged = null
    this.save()
  }

  save() {
    const order = this.tabTargets.map((tab) => tab.dataset.tabKey)
    const token = document.querySelector("meta[name=csrf-token]")?.content
    fetch(this.urlValue, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token, Accept: "application/json" },
      body: JSON.stringify({ order })
    })
  }
}
