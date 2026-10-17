import { Controller } from "@hotwired/stimulus"

// Dynamic list of chain steps: add from a <template>, remove, and keep 1..n numbering.
export default class extends Controller {
  static targets = ["list", "template", "item", "number"]

  connect() {
    this.renumber()
  }

  add() {
    const index = Date.now()
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replaceAll("NEW_INDEX", index))
    this.renumber()
    this.listTarget.lastElementChild.querySelector("input")?.focus()
  }

  remove({ currentTarget }) {
    if (this.itemTargets.length > 1) currentTarget.closest("[data-steps-target='item']").remove()
    this.renumber()
  }

  renumber() {
    this.numberTargets.forEach((el, i) => (el.textContent = i + 1))
  }
}
